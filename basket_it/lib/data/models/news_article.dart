import 'package:flutter/foundation.dart';

/// 뉴스 분류: KBL 소식 / 해외파 한국 선수 소식.
enum NewsCategory { kbl, overseas, nba }

extension NewsCategoryLabel on NewsCategory {
  String get label => switch (this) {
    NewsCategory.kbl => 'KBL',
    NewsCategory.overseas => '해외파',
    NewsCategory.nba => 'NBA',
  };

  /// 서버(getBasketballNews)가 쓰는 문자열 값.
  String get wireName => switch (this) {
    NewsCategory.kbl => 'kbl',
    NewsCategory.overseas => 'overseas',
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
  final String? thumbnailUrl;

  /// 원문 링크. 카드를 누르면 이 주소를 웹뷰로 연다.
  final String? url;

  /// 기사와 관련된 팀 id (팀 컬러·로고 연결에 쓴다).
  final String? relatedTeamId;

  /// 배지에 쓸 팀 표기. KBL 기사면 구단명, 해외파 기사면 '해외파'.
  final String? teamLabel;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.category,
    this.summary,
    this.thumbnailUrl,
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

    final category = switch (json['category']) {
      'overseas' => NewsCategory.overseas,
      'nba' => NewsCategory.nba,
      _ => NewsCategory.kbl,
    };
    final description = json['description'] as String?;

    return NewsArticle(
      id: articleUrl,
      title: title,
      source: json['source'] as String? ?? '',
      publishedAt: publishedAt.toLocal(),
      category: category,
      summary: (description == null || description.isEmpty) ? null : description,
      thumbnailUrl: json['thumbnail_url'] as String?,
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
