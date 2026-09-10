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
///
/// 뉴스를 못 가져왔을 때 대신 보여줄 가짜 기사 같은 건 두지 않는다.
/// 지어낸 선수와 지어낸 경기 결과가 진짜 기사처럼 보이기 때문이다.
/// 실패하면 [NewsUnavailableException]을 던지고 화면은 오류 상태를 보여준다.
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
