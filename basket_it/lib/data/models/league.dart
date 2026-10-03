/// 리그 구분.
///
/// 기록·일정·순위는 KBL만 다룬다(NBA는 쓰던 기록 API를 더 쓸 수 없게 되어
/// 앱에서 내렸다). NBA는 뉴스 섹션에서만 남아 있다.
enum League {
  kbl,
  nba;

  String get label => switch (this) {
    League.kbl => 'KBL',
    League.nba => 'NBA',
  };

  /// 정적 JSON 경로와 뉴스 분류에 쓰는 문자열.
  String get wireName => switch (this) {
    League.kbl => 'kbl',
    League.nba => 'nba',
  };
}
