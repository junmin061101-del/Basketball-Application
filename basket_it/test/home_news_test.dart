import 'package:basket_it/core/theme/app_theme.dart';
import 'package:basket_it/data/models/news_article.dart';
import 'package:basket_it/data/repositories/news_repository.dart';
import 'package:basket_it/features/home/home_tab.dart';
import 'package:basket_it/providers/news_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 카테고리별로 무엇을 요청받았는지 기록하는 가짜 Repository.
class _FakeNewsRepository implements NewsRepository {
  final List<NewsArticle> articles;
  final List<NewsCategory?> requested = [];

  _FakeNewsRepository(this.articles);

  @override
  Future<List<NewsArticle>> getNews({NewsCategory? category}) async {
    requested.add(category);
    if (category == null) return articles;
    return articles.where((a) => a.category == category).toList();
  }
}

/// 항상 실패하는 Repository. 샘플 폴백이 도는지 확인하는 데 쓴다.
class _BrokenNewsRepository implements NewsRepository {
  @override
  Future<List<NewsArticle>> getNews({NewsCategory? category}) async {
    throw const NewsUnavailableException('뉴스 서버 설정이 아직 끝나지 않았어요.');
  }
}

NewsArticle article({
  required String id,
  required String title,
  NewsCategory category = NewsCategory.kbl,
  String? summary,
  String? teamLabel,
  required Duration ago,
}) => NewsArticle(
  id: id,
  title: title,
  source: '점프볼',
  publishedAt: DateTime.now().subtract(ago),
  category: category,
  summary: summary,
  url: id,
  teamLabel: teamLabel,
);

Future<void> pumpHome(
  WidgetTester tester,
  NewsRepository repository, {
  List<NewsArticle>? opened,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        newsRepositoryProvider.overrideWithValue(repository),
        if (opened != null)
          articleOpenerProvider.overrideWithValue((context, article) async {
            opened.add(article);
          }),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const HomeTab()),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle(const Duration(milliseconds: 600));
}

void main() {
  final feed = [
    article(
      id: 'https://jumpball.co.kr/news/1',
      title: '서울 SK, 창원 LG 꺾고 4연승',
      summary: '리바운드를 장악하며 승리했다.',
      teamLabel: '서울 SK',
      ago: const Duration(minutes: 20),
    ),
    article(
      id: 'https://basketkorea.com/news/2',
      title: '안양 정관장 5연승 단독 선두',
      ago: const Duration(hours: 3),
    ),
    article(
      id: 'https://rookie.co.kr/news/3',
      title: '이현중, G리그 데뷔전 18득점',
      category: NewsCategory.overseas,
      teamLabel: '해외파',
      ago: const Duration(hours: 5),
    ),
  ];

  testWidgets('뉴스 카드 리스트가 헤드라인 + 목록으로 구성된다', (tester) async {
    await pumpHome(tester, _FakeNewsRepository(feed));

    // 세 기사 모두 카드로 그려진다.
    expect(find.text('서울 SK, 창원 LG 꺾고 4연승'), findsOneWidget);
    expect(find.text('안양 정관장 5연승 단독 선두'), findsOneWidget);
    expect(find.text('이현중, G리그 데뷔전 18득점'), findsOneWidget);

    // 맨 위 기사만 요약과 팀 배지를 함께 보여준다(헤드라인 카드).
    expect(find.text('리바운드를 장악하며 승리했다.'), findsOneWidget);
    expect(find.text('서울 SK'), findsOneWidget);

    // 분류·언론사·시간 줄.
    expect(find.text('점프볼 · 20분 전'), findsOneWidget);
    expect(find.text('점프볼 · 3시간 전'), findsOneWidget);
  });

  testWidgets('목록 카드를 누르면 그 기사의 원문 링크를 연다', (tester) async {
    final opened = <NewsArticle>[];
    await pumpHome(tester, _FakeNewsRepository(feed), opened: opened);

    await tester.tap(find.text('안양 정관장 5연승 단독 선두'));
    await tester.pump();

    expect(opened, hasLength(1));
    expect(opened.single.url, 'https://basketkorea.com/news/2');
  });

  testWidgets('헤드라인 카드를 누르면 그 기사의 원문 링크를 연다', (tester) async {
    final opened = <NewsArticle>[];
    await pumpHome(tester, _FakeNewsRepository(feed), opened: opened);

    await tester.tap(find.text('서울 SK, 창원 LG 꺾고 4연승'));
    await tester.pump();

    expect(opened, hasLength(1));
    expect(opened.single.url, 'https://jumpball.co.kr/news/1');
  });

  testWidgets('필터를 바꾸면 그 분류로 다시 요청한다', (tester) async {
    final repository = _FakeNewsRepository(feed);
    await pumpHome(tester, repository);
    expect(repository.requested, [null]);

    await tester.tap(find.text('해외파').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(repository.requested, [null, NewsCategory.overseas]);
    // 해외파 기사만 남는다.
    expect(find.text('이현중, G리그 데뷔전 18득점'), findsOneWidget);
    expect(find.text('서울 SK, 창원 LG 꺾고 4연승'), findsNothing);
  });

  testWidgets('뉴스 서버를 못 부르면 샘플임을 분명히 알린다', (tester) async {
    await pumpHome(tester, _BrokenNewsRepository());

    expect(
      find.textContaining('샘플 기사를 보여주고 있어요'),
      findsOneWidget,
      reason: '가짜 기사가 진짜처럼 보이면 안 된다',
    );
  });
}
