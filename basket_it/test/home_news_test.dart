import 'package:basket_it/core/theme/app_theme.dart';
import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/data/models/news_article.dart';
import 'package:basket_it/data/models/team.dart';
import 'package:basket_it/data/models/team_standing.dart';
import 'package:basket_it/data/repositories/news_repository.dart';
import 'package:basket_it/features/home/home_tab.dart';
import 'package:basket_it/providers/game_providers.dart';
import 'package:basket_it/providers/news_providers.dart';
import 'package:basket_it/providers/onboarding_providers.dart';
import 'package:basket_it/providers/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';

/// 칩 테스트에 쓰는 팀. 실제 KBL 데이터는 네트워크에서 오므로 여기서 넣어 준다.
const testTeams = [
  Team(id: 'sk', city: '서울', name: 'SK', shortName: 'SK', primaryColor: Color(0xFFAB0028)),
  Team(id: 'lg', city: '창원', name: 'LG', shortName: 'LG', primaryColor: Color(0xFF550E10)),
  Team(id: 'kgc', city: '안양', name: '정관장', shortName: '정관장', primaryColor: Color(0xFFCF1F25)),
  Team(id: 'kcc', city: '부산', name: 'KCC', shortName: 'KCC', primaryColor: Color(0xFF07215A)),
];

/// 카테고리별로 무엇을 요청받았는지 기록하는 가짜 Repository.
class _FakeNewsRepository implements NewsRepository {
  final List<NewsArticle> articles;
  final List<NewsCategory?> requested = [];

  _FakeNewsRepository(this.articles);

  @override
  Future<List<NewsArticle>> getNews({NewsCategory? category}) async {
    requested.add(category);
    return switch (category) {
      null => articles,
      _ => articles.where((a) => a.category == category).toList(),
    };
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
  Set<String> followedTeamIds = const {},
  List<TeamStanding> standings = const [],
  StandingsSeason season = const StandingsSeason(),
  List<Game> games = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        newsRepositoryProvider.overrideWithValue(repository),
        teamRepositoryProvider.overrideWithValue(
          FakeTeamRepository(testTeams, standings, season),
        ),
        playerRepositoryProvider.overrideWithValue(
          const FakePlayerRepository(),
        ),
        gameRepositoryProvider.overrideWithValue(FakeGameRepository(games)),
        followedTeamIdsProvider.overrideWith((ref) => followedTeamIds),
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
      title: '부산 KCC, 새 외국인 선수 영입',
      ago: const Duration(hours: 5),
    ),
  ];

  testWidgets('뉴스 카드 리스트가 헤드라인 + 목록으로 구성된다', (tester) async {
    await pumpHome(tester, _FakeNewsRepository(feed));

    // 세 기사 모두 카드로 그려진다.
    expect(find.text('서울 SK, 창원 LG 꺾고 4연승'), findsOneWidget);
    expect(find.text('안양 정관장 5연승 단독 선두'), findsOneWidget);
    expect(find.text('부산 KCC, 새 외국인 선수 영입'), findsOneWidget);

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

    // 뉴스는 내 팀 카드 아래에 있어 스크롤해서 누른다.
    await tester.ensureVisible(find.text('안양 정관장 5연승 단독 선두'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('안양 정관장 5연승 단독 선두'));
    await tester.pump();

    expect(opened, hasLength(1));
    expect(opened.single.url, 'https://basketkorea.com/news/2');
  });

  testWidgets('헤드라인 카드를 누르면 그 기사의 원문 링크를 연다', (tester) async {
    final opened = <NewsArticle>[];
    await pumpHome(tester, _FakeNewsRepository(feed), opened: opened);

    await tester.ensureVisible(find.text('서울 SK, 창원 LG 꺾고 4연승'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('서울 SK, 창원 LG 꺾고 4연승'));
    await tester.pump();

    expect(opened, hasLength(1));
    expect(opened.single.url, 'https://jumpball.co.kr/news/1');
  });

  testWidgets('뉴스는 KBL / NBA 두 섹션뿐이고 리그 전환을 따라간다', (tester) async {
    final repository = _FakeNewsRepository([
      ...feed,
      article(
        id: 'https://jumpball.co.kr/news/9',
        title: '돈치치 40득점, 레이커스 역전승',
        category: NewsCategory.nba,
        ago: const Duration(minutes: 5),
      ),
    ]);
    await pumpHome(tester, repository);

    // KBL 섹션: KBL 기사만, NBA 기사는 섞이지 않는다.
    expect(repository.requested, [NewsCategory.kbl]);
    expect(find.text('KBL 뉴스'), findsOneWidget);
    expect(find.text('서울 SK, 창원 LG 꺾고 4연승'), findsOneWidget);
    expect(find.text('돈치치 40득점, 레이커스 역전승'), findsNothing);
    // 전체/해외파 같은 분류 칩은 없다.
    expect(find.text('전체'), findsNothing);
    expect(find.text('해외파'), findsNothing);

    // 맨 위 리그 전환을 NBA로 바꾸면 NBA 섹션으로 바뀐다.
    await tester.tap(find.text('NBA').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(repository.requested.last, NewsCategory.nba);
    expect(find.text('NBA 뉴스'), findsOneWidget);
    expect(find.text('돈치치 40득점, 레이커스 역전승'), findsOneWidget);
    expect(find.text('서울 SK, 창원 LG 꺾고 4연승'), findsNothing);
  });

  testWidgets('뉴스를 못 불러오면 오류를 보여주고 가짜 기사는 절대 안 보여준다', (tester) async {
    await pumpHome(tester, _BrokenNewsRepository());

    // 실패했을 때 지어낸 기사를 대신 채우면 진짜 기사처럼 읽힌다.
    // 공개 서비스에서는 하면 안 되므로, 실패는 실패로 보여준다.
    expect(find.textContaining('뉴스 서버 설정이 아직 끝나지 않았어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);

    // 기사 카드가 하나도 그려지지 않아야 한다.
    expect(find.byType(Card), findsNothing);
    for (final fake in ['정승우', '서준영', '박준혁', '트리플더블']) {
      expect(
        find.textContaining(fake),
        findsNothing,
        reason: '$fake 같은 지어낸 내용이 화면에 나오면 안 된다',
      );
    }
  });

  testWidgets('팔로우한 팀이 없으면 내 팀을 고르라는 카드가 뉴스보다 먼저 나온다', (tester) async {
    await pumpHome(tester, _FakeNewsRepository(feed));

    expect(find.text('내 팀을 정해 보세요'), findsOneWidget);
    expect(find.text('팀 고르기'), findsOneWidget);
    final card = tester.getTopLeft(find.text('내 팀을 정해 보세요'));
    final news = tester.getTopLeft(find.text('KBL 뉴스'));
    expect(card.dy, lessThan(news.dy));
  });

  testWidgets('내 팀 카드: 순위·연승·앞뒤 팀 게임차·최근 5경기·최근 경기', (tester) async {
    final now = DateTime.now();
    Game g(String id, int daysAgo, String home, int hs, String away, int as) {
      final start = DateTime(now.year, now.month, now.day, 19)
          .subtract(Duration(days: daysAgo));
      return Game(
        id: id,
        date: DateTime(start.year, start.month, start.day),
        homeTeamId: home,
        awayTeamId: away,
        homeScore: hs,
        awayScore: as,
        status: GameStatus.finished,
        startTime: start,
      );
    }

    await pumpHome(
      tester,
      _FakeNewsRepository(feed),
      followedTeamIds: {'sk'},
      standings: const [
        TeamStanding(teamId: 'lg', wins: 36, losses: 18, gamesBehind: 0),
        TeamStanding(teamId: 'sk', wins: 35, losses: 19, gamesBehind: 1),
        TeamStanding(teamId: 'kgc', wins: 33, losses: 21, gamesBehind: 3),
        TeamStanding(teamId: 'kcc', wins: 30, losses: 24, gamesBehind: 6),
      ],
      season: const StandingsSeason(label: '2025-26', isFinal: true),
      games: [
        g('1', 5, 'sk', 70, 'lg', 80), // 패
        g('2', 3, 'kgc', 60, 'sk', 75), // 승
        g('3', 1, 'sk', 80, 'kcc', 70), // 승 (가장 최근)
      ],
    );

    expect(find.text('내 팀'), findsOneWidget);
    expect(find.text('2위'), findsOneWidget);
    expect(find.text('2연승'), findsOneWidget);
    expect(find.text('1위 LG와 1게임차', findRichText: true), findsOneWidget);
    expect(find.text('3위 정관장과 2게임차', findRichText: true), findsOneWidget);
    expect(find.text('2025-26 시즌 최종 · 35승 19패'), findsOneWidget);
    expect(find.text('최근 5경기'), findsOneWidget);
    expect(find.text('승'), findsNWidgets(2));
    expect(find.text('패'), findsOneWidget);
    // 오늘 경기가 없으니 가장 최근 경기를 크게 보여준다
    expect(find.textContaining('최근 경기 · '), findsOneWidget);
    expect(find.text('80 : 70'), findsOneWidget);
    expect(find.text('경기 종료'), findsOneWidget);

    // 내 팀 카드가 뉴스보다 위에 있다
    expect(
      tester.getTopLeft(find.text('2위')).dy,
      lessThan(tester.getTopLeft(find.text('KBL 뉴스')).dy),
    );
  });

  testWidgets('팔로우한 팀이 여럿이면 카드 위에서 팀을 고른다', (tester) async {
    await pumpHome(
      tester,
      _FakeNewsRepository(feed),
      followedTeamIds: {'sk', 'lg'},
    );

    // 고르기 칩은 팔로우한 팀만(로고가 없는 테스트 팀은 칩·카드 로고 자리에도
    // 이름 글자가 그려져 여러 번 잡힌다)
    expect(find.text('SK'), findsWidgets);
    expect(find.text('LG'), findsWidgets);
    expect(find.text('정관장'), findsNothing);
    expect(find.text('KCC'), findsNothing);
    expect(find.text('창원 LG'), findsNothing);

    await tester.tap(find.text('LG').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('창원 LG'), findsOneWidget); // 카드 제목이 바뀐다
  });
}
