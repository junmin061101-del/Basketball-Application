import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;

import '../models/news_article.dart';

/// 뉴스 데이터 접근을 추상화한 Repository.
///
/// 구현이 셋 있고, 주입 지점(`newsRepositoryProvider`) 한 줄만 바꾸면 된다.
///
/// - [StaticJsonNewsRepository] — 현재 사용. GitHub Actions가 20분마다 모아
///   GitHub Pages에 올려둔 JSON을 읽는다. 무료 요금제로 운영할 수 있고,
///   Client ID/Secret이 앱에 들어가지 않는다.
/// - [FunctionsNewsRepository] — Firebase Blaze 요금제로 올라갈 경우.
///   호출할 때마다 실시간으로 네이버를 검색한다.
/// - [MockNewsRepository] — 네트워크 없이 UI만 확인할 때.
abstract class NewsRepository {
  /// 최신순으로 정렬된 뉴스 목록. [category]가 null이면 KBL+해외파 전체.
  Future<List<NewsArticle>> getNews({NewsCategory? category});
}

/// 뉴스를 가져오지 못했을 때 던지는 예외. 화면에 그대로 보여줄 한국어 메시지를 담는다.
class NewsUnavailableException implements Exception {
  final String message;
  const NewsUnavailableException(this.message);

  @override
  String toString() => message;
}

/// GitHub Pages에 올라간 정적 JSON을 읽는 구현.
///
/// 수집은 서버(GitHub Actions)에서 끝나 있고 앱은 결과만 가져온다.
/// 응답 형태는 Cloud Functions 버전과 같아서 화면 코드는 그대로 쓴다.
class StaticJsonNewsRepository implements NewsRepository {
  /// 뉴스 JSON이 놓인 위치. 저장소·계정이 바뀌면
  /// `--dart-define=NEWS_BASE_URL=...`로 덮어쓸 수 있다.
  static const defaultBaseUrl = String.fromEnvironment(
    'NEWS_BASE_URL',
    defaultValue:
        'https://junmin061101-del.github.io/Basketball-Application/news',
  );

  final String baseUrl;
  final http.Client _client;

  StaticJsonNewsRepository({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? defaultBaseUrl,
      _client = client ?? http.Client();

  @override
  Future<List<NewsArticle>> getNews({NewsCategory? category}) async {
    final name = category?.wireName ?? 'all';
    final uri = Uri.parse('$baseUrl/$name.json');

    final http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const NewsUnavailableException('네트워크 연결을 확인해주세요.');
    }

    if (response.statusCode == 404) {
      // 아직 수집이 한 번도 안 돌았을 때.
      throw const NewsUnavailableException('아직 수집된 뉴스가 없어요.');
    }
    if (response.statusCode != 200) {
      throw const NewsUnavailableException('뉴스를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
    }

    final Object? decoded;
    try {
      // 한글이 깨지지 않도록 바이트를 직접 UTF-8로 읽는다.
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const NewsUnavailableException('뉴스 형식을 읽지 못했어요.');
    }
    if (decoded is! Map) return const [];

    return _parseArticles(decoded['articles']);
  }
}

/// 서버가 준 기사 배열을 모델 목록으로 바꾼다.
/// 원문 URL이 같은 기사는 한 번만 남기고 최신순으로 정렬한다.
List<NewsArticle> _parseArticles(Object? raw) {
  if (raw is! List) return const [];
  final articles = <NewsArticle>[];
  final seen = <String>{};
  for (final item in raw) {
    if (item is! Map) continue;
    final article = NewsArticle.tryParse(item.cast<Object?, Object?>());
    if (article != null && seen.add(article.id)) articles.add(article);
  }
  articles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return articles;
}

/// 네이버 뉴스 검색의 정렬 방식.
enum NewsSort {
  /// 최신순(네이버 sort=date). 뉴스 피드의 기본값.
  date,

  /// 정확도순(네이버 sort=sim).
  similarity;

  String get wireName => switch (this) {
    NewsSort.date => 'date',
    NewsSort.similarity => 'sim',
  };
}

/// Cloud Functions(`getBasketballNews`) 기반 구현.
class FunctionsNewsRepository implements NewsRepository {
  /// 함수를 배포한 리전. functions/index.js의 region과 같아야 한다.
  static const region = 'asia-northeast3';

  final FirebaseFunctions _functions;

  /// 서버에 요청할 정렬 방식. 홈 피드는 최신순이 자연스럽다.
  final NewsSort sort;

  FunctionsNewsRepository({
    FirebaseFunctions? functions,
    this.sort = NewsSort.date,
  }) : _functions = functions ?? FirebaseFunctions.instanceFor(region: region);

  @override
  Future<List<NewsArticle>> getNews({NewsCategory? category}) async {
    final callable = _functions.httpsCallable(
      'getBasketballNews',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    final HttpsCallableResult result;
    try {
      result = await callable.call<Map<String, dynamic>>({
        'category': category?.wireName ?? 'all',
        'sort': sort.wireName,
      });
    } on FirebaseFunctionsException catch (e) {
      throw NewsUnavailableException(_messageFor(e));
    } catch (_) {
      throw const NewsUnavailableException('뉴스를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
    }

    return _parseArticles(result.data['articles']);
  }

  String _messageFor(FirebaseFunctionsException e) => switch (e.code) {
    'failed-precondition' => '뉴스 서버 설정이 아직 끝나지 않았어요.',
    'deadline-exceeded' => '뉴스를 가져오는 데 시간이 너무 오래 걸렸어요.',
    'unavailable' => '네트워크 연결을 확인해주세요.',
    _ => '뉴스를 불러오지 못했어요. 잠시 후 다시 시도해주세요.',
  };
}

/// 네트워크 없이 홈 탭 UI만 확인할 때 쓰는 목업. 실제 서비스에는 쓰지 않는다.
class MockNewsRepository implements NewsRepository {
  @override
  Future<List<NewsArticle>> getNews({NewsCategory? category}) async {
    await Future.delayed(const Duration(milliseconds: 450));
    final now = DateTime.now();
    final all = _articles(now)
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    if (category == null) return all;
    return all.where((a) => a.category == category).toList();
  }

  List<NewsArticle> _articles(DateTime now) => [
    NewsArticle(
      id: 'n1',
      title: '정승우, 시즌 3번째 트리플더블…KCC 연장 접전 끝 승리',
      source: '점프볼',
      publishedAt: now.subtract(const Duration(minutes: 35)),
      category: NewsCategory.kbl,
      relatedTeamId: 'kcc',
      teamLabel: '부산 KCC',
      summary: '4쿼터 막판 동점 3점슛에 이어 연장에서 결승 득점까지. 부산 KCC가 홈에서 원주 DB를 꺾었다.',
    ),
    NewsArticle(
      id: 'n2',
      title: '서준영 "우승 반지 끼고 싶다"…원주 DB 재계약 협상 급물살',
      source: '바스켓코리아',
      publishedAt: now.subtract(const Duration(hours: 2, minutes: 10)),
      category: NewsCategory.kbl,
      relatedTeamId: 'db',
      teamLabel: '원주 DB',
      summary: '리그 최다 팔로워 선수 서준영이 잔류 의사를 밝혔다. 구단은 다년 계약을 제안한 것으로 알려졌다.',
    ),
    NewsArticle(
      id: 'n3',
      title: '[해외파] 박준혁, G리그 데뷔전 18득점 7리바운드 "적응 끝났다"',
      source: '루키',
      publishedAt: now.subtract(const Duration(hours: 3)),
      category: NewsCategory.overseas,
      teamLabel: '해외파',
      summary: '미국 진출 한국 선수 박준혁이 첫 경기부터 존재감을 보였다. 현지 언론도 "즉시 전력감"이라 평가.',
    ),
    NewsArticle(
      id: 'n4',
      title: '안양 정관장, 5연승으로 단독 선두…오지훈 리그 MVP 후보 급부상',
      source: '스포츠조선',
      publishedAt: now.subtract(const Duration(hours: 5)),
      category: NewsCategory.kbl,
      relatedTeamId: 'kgc',
      teamLabel: '안양 정관장',
    ),
    NewsArticle(
      id: 'n5',
      title: '[해외파] 김도현, 스페인 ACB 리그 이적 확정…"유럽에서 증명하겠다"',
      source: '점프볼',
      publishedAt: now.subtract(const Duration(hours: 7, minutes: 20)),
      category: NewsCategory.overseas,
      teamLabel: '해외파',
      summary: '국내 리그 출신 포워드 김도현이 스페인 1부 리그 구단과 2년 계약에 합의했다.',
    ),
    NewsArticle(
      id: 'n6',
      title: '서울 SK, 김선우 발목 부상으로 2주 결장…플레이오프 변수',
      source: '바스켓코리아',
      publishedAt: now.subtract(const Duration(hours: 11)),
      category: NewsCategory.kbl,
      relatedTeamId: 'sk',
      teamLabel: '서울 SK',
    ),
    NewsArticle(
      id: 'n7',
      title: 'KBL 올스타전 팬 투표 개막…첫날 1위는 임도윤',
      source: 'KBL',
      publishedAt: now.subtract(const Duration(days: 1, hours: 1)),
      category: NewsCategory.kbl,
      relatedTeamId: 'mobis',
      teamLabel: '울산 현대모비스',
    ),
    NewsArticle(
      id: 'n8',
      title: '[해외파] 이승현, NCAA 컨퍼런스 이주의 선수 선정',
      source: '루키',
      publishedAt: now.subtract(const Duration(days: 1, hours: 6)),
      category: NewsCategory.overseas,
      teamLabel: '해외파',
    ),
    NewsArticle(
      id: 'n9',
      title: '창원 LG 전현식, 블록 8개로 시즌 한 경기 최다 기록 경신',
      source: '스포츠조선',
      publishedAt: now.subtract(const Duration(days: 2)),
      category: NewsCategory.kbl,
      relatedTeamId: 'lg',
      teamLabel: '창원 LG',
    ),
    NewsArticle(
      id: 'n10',
      title: '[해외파] 최민재, 일본 B리그 시즌 첫 더블더블…팀 3연승 견인',
      source: '바스켓코리아',
      publishedAt: now.subtract(const Duration(days: 2, hours: 9)),
      category: NewsCategory.overseas,
      teamLabel: '해외파',
    ),
    NewsArticle(
      id: 'n11',
      title: '고양 소노, 홈 10연패 끝…최준우 30득점 폭발',
      source: '점프볼',
      publishedAt: now.subtract(const Duration(days: 3)),
      category: NewsCategory.kbl,
      relatedTeamId: 'sono',
      teamLabel: '고양 소노',
    ),
    NewsArticle(
      id: 'n12',
      title: '대구 한국가스공사, 송민석 중심 리바운드 1위…"골밑 지배력이 승리 비결"',
      source: 'KBL',
      publishedAt: now.subtract(const Duration(days: 4, hours: 2)),
      category: NewsCategory.kbl,
      relatedTeamId: 'kogas',
      teamLabel: '대구 한국가스공사',
    ),
  ];
}
