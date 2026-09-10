/// 앱이 다루는 리그.
///
/// 홈·게임·탐색 탭이 이 값에 따라 완전히 다른 데이터를 보여준다.
/// 예측과 커뮤니티는 두 리그를 한곳에서 다룬다(사용자가 갈리면 게시판과
/// 순위표 표본이 양쪽 다 얇아진다).
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
