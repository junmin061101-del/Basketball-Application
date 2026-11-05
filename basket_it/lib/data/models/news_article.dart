import 'package:flutter/foundation.dart';

/// 뉴스 분류: KBL 소식 / NBA 소식. 두 리그를 섞지 않는다.
enum NewsCategory { kbl, nba }

extension NewsCategoryLabel on NewsCategory {
  String get label => switch (this) {
    NewsCategory.kbl => 'KBL',
    NewsCategory.nba => 'NBA',
  };

  /// 서버(getBasketballNews)가 쓰는 문자열 값.
  String get wireName => switch (this) {
    NewsCategory.kbl => 'kbl',
    NewsCategory.nba => 'nba',
  };
}

/// 뉴스 기사 한 건.
///
/// 서버 함수 `getBasketballNews`가 돌려주는 스네이크 케이스 응답
/// (category / team / source / pub_date / title / description /
/// article_url / thumbnail_url)을 그대로 담는다.
@immutable
class NewsArticle {
  /// 기사 식별자. 원문 URL이 곧 고유 키라서 중복 제거에도 이 값을 쓴다.
  final String id;
  final String title;
  final String source; // 언론사
  final DateTime publishedAt;
  final NewsCategory category;

  /// 기사 요약(네이버 검색 결과의 description에서 태그를 뗀 것).
  final String? summary;

  /// 머리기사 카드 사진. 수집기가 줄여 올린 사진(720×400)이 있으면 그것,
  /// 없으면 언론사 원본.
  final String? thumbnailUrl;

  /// 목록 한 줄의 작은 사진(160px). 수집기가 줄여 올린 것만 쓴다. 언론사
  /// 원본은 무겁고 절반은 CORS가 없어, 목록마다 깔면 웹에서 스크롤이 끊긴다.
  final String? smallThumbnailUrl;

  /// 원문 링크. 카드를 누르면 이 주소를 웹뷰로 연다.
  final String? url;

  /// 기사와 관련된 팀 id (팀 컬러·로고 연결에 쓴다).
  final String? relatedTeamId;

  /// 배지에 쓸 팀 표기(구단명). 팀을 못 찾은 기사는 null.
  final String? teamLabel;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.category,
    this.summary,
    this.thumbnailUrl,
    this.smallThumbnailUrl,
    this.url,
    this.relatedTeamId,
    this.teamLabel,
  });

  /// 서버 응답 한 건을 모델로 바꾼다. 형식이 어긋나면 null.
  static NewsArticle? tryParse(Map<Object?, Object?> json) {
    final articleUrl = json['article_url'] as String?;
    final title = json['title'] as String?;
    final pubDate = json['pub_date'] as String?;
    if (articleUrl == null || title == null || pubDate == null) return null;

    final publishedAt = DateTime.tryParse(pubDate);
    if (publishedAt == null) return null;

    // KBL / NBA가 아닌 기사(예전 수집 결과의 해외파 등)는 받지 않는다.
    final category = switch (json['category']) {
      'kbl' => NewsCategory.kbl,
      'nba' => NewsCategory.nba,
      _ => null,
    };
    if (category == null) return null;
    final description = json['description'] as String?;

    return NewsArticle(
      id: articleUrl,
      title: _plainTilde(title),
      source: json['source'] as String? ?? '',
      publishedAt: publishedAt.toLocal(),
      category: category,
      summary: (description == null || description.isEmpty)
          ? null
          : _plainTilde(description),
      thumbnailUrl:
          json['thumb_url'] as String? ?? json['thumbnail_url'] as String?,
      smallThumbnailUrl: json['thumb_small_url'] as String?,
      url: articleUrl,
      relatedTeamId: json['team_id'] as String?,
      teamLabel: json['team'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is NewsArticle && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 기사에서 범위를 나타내는 '∼'(수학 기호)를 '~'로 바꾼다. 앱 글꼴에 '∼'가
/// 없어서, 한 글자 때문에 웹 앱이 스크롤 중 수학 기호 글꼴(226KB)을 받아 왔다.
String _plainTilde(String text) => text.replaceAll('\u223C', '~');
