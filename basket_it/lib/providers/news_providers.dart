import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/news_article.dart';
import '../data/repositories/news_repository.dart';
import '../features/home/article_view_screen.dart';

/// 실제 뉴스 주입 지점.
///
/// GitHub Actions가 20분마다 네이버에서 모아 GitHub Pages에 올려둔 JSON을
/// 읽는다. Firebase Blaze 요금제로 올라가 실시간 검색을 쓰고 싶으면 이 줄만
/// `FunctionsNewsRepository()`로 바꾸면 된다.
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return StaticJsonNewsRepository();
});

/// 기사를 여는 방법. 기본은 앱 안 웹뷰(웹 빌드는 새 탭)이며,
/// 테스트에서는 이 provider를 덮어써 실제로 어떤 기사가 열렸는지 확인한다.
typedef ArticleOpener = Future<void> Function(BuildContext, NewsArticle);

final articleOpenerProvider = Provider<ArticleOpener>((ref) => openArticle);

/// 홈 탭에서 선택된 뉴스 분류. null이면 전체.
final newsCategoryFilterProvider = StateProvider<NewsCategory?>((ref) => null);

/// 뉴스를 다시 확인하는 주기.
///
/// 원본이 20분마다 갱신되므로 그보다 자주 물어봐야 새 기사가 생기지 않는다.
/// 실시간 검색(Cloud Functions)으로 바꾸면 90초 정도로 줄이면 된다.
const newsPollInterval = Duration(minutes: 5);

/// 한 화면에 들고 있는 기사 수 상한. 폴링으로 계속 합치기만 하면 끝없이 쌓인다.
const _maxArticles = 60;

/// 홈 탭 뉴스 피드 상태.
class NewsFeed {
  final List<NewsArticle> articles;

  /// 마지막으로 서버에서 새로 받아온 시각.
  final DateTime updatedAt;

  /// 이번 폴링에서 새로 들어온 기사 수(0이면 변화 없음).
  final int newCount;

  const NewsFeed({
    required this.articles,
    required this.updatedAt,
    this.newCount = 0,
  });
}

/// 선택된 분류의 뉴스 피드.
///
/// 처음 한 번 불러온 뒤 [newsPollInterval]마다 다시 확인해, 새로 올라온
/// 기사만 원문 URL 기준으로 중복을 걸러 앞에 합친다. 폴링 중에는 로딩
/// 상태로 되돌리지 않아 화면이 깜빡이지 않는다.
final newsFeedProvider =
    AsyncNotifierProvider.autoDispose<NewsFeedNotifier, NewsFeed>(
      NewsFeedNotifier.new,
    );

class NewsFeedNotifier extends AutoDisposeAsyncNotifier<NewsFeed> {
  Timer? _timer;
  bool _polling = false;

  @override
  Future<NewsFeed> build() async {
    final category = ref.watch(newsCategoryFilterProvider);
    final repository = ref.watch(newsRepositoryProvider);

    _timer?.cancel();
    _timer = Timer.periodic(newsPollInterval, (_) => _poll());
    ref.onDispose(() => _timer?.cancel());

    // 실패하면 그대로 예외를 올린다. 가짜 기사로 대신 채우지 않는다.
    final articles = await repository.getNews(category: category);
    return NewsFeed(articles: articles, updatedAt: DateTime.now());
  }

  /// 사용자가 당겨서 새로고침했을 때. 로딩 스피너 없이 목록만 갱신한다.
  Future<void> refresh() => _poll();

  /// 오류 상태에서 "다시 시도"를 눌렀을 때는 로딩부터 다시 시작한다.
  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  Future<void> _poll() async {
    if (_polling) return; // 앞선 요청이 아직 안 끝났으면 건너뛴다
    _polling = true;
    try {
      final category = ref.read(newsCategoryFilterProvider);
      final fetched = await ref
          .read(newsRepositoryProvider)
          .getNews(category: category);

      final previous = state.valueOrNull;
      if (previous == null) {
        state = AsyncValue.data(
          NewsFeed(articles: fetched, updatedAt: DateTime.now()),
        );
        return;
      }
      state = AsyncValue.data(_merge(previous, fetched));
    } catch (_) {
      // 폴링 실패는 조용히 넘긴다. 이미 보여주고 있는 기사를 지울 이유가 없다.
    } finally {
      _polling = false;
    }
  }

  /// 새로 받은 목록을 기존 목록과 합친다. 같은 원문 URL은 한 번만 남기고,
  /// 서버가 다시 준 쪽(썸네일이 채워졌을 수 있다)을 우선한다.
  NewsFeed _merge(NewsFeed previous, List<NewsArticle> fetched) {
    final byUrl = <String, NewsArticle>{};
    for (final article in fetched) {
      byUrl[article.id] = article;
    }
    var newCount = 0;
    final previousIds = {for (final a in previous.articles) a.id};
    for (final article in fetched) {
      if (!previousIds.contains(article.id)) newCount++;
    }
    for (final article in previous.articles) {
      byUrl.putIfAbsent(article.id, () => article);
    }

    final merged = byUrl.values.toList()
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return NewsFeed(
      articles: merged.take(_maxArticles).toList(),
      updatedAt: DateTime.now(),
      newCount: newCount,
    );
  }
}
