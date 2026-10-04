import 'package:flutter/foundation.dart';

/// 라인업의 다섯 자리.
enum LineupSlot {
  pg('PG', '포인트 가드'),
  sg('SG', '슈팅 가드'),
  sf('SF', '스몰 포워드'),
  pf('PF', '파워 포워드'),
  c('C', '센터');

  final String label;
  final String korean;

  const LineupSlot(this.label, this.korean);
}

/// KBL이 알려주는 선수 분류(가드·포워드·센터).
enum PlayerLine {
  guard('G', '가드'),
  forward('F', '포워드'),
  center('C', '센터');

  final String code;
  final String korean;

  const PlayerLine(this.code, this.korean);

  static PlayerLine? parse(String? value) => switch (value) {
    'G' => PlayerLine.guard,
    'F' => PlayerLine.forward,
    'C' => PlayerLine.center,
    _ => null,
  };
}

/// 한 시대에 한 구단에서 뛴 실제 KBL 선수. 기록은 그 시즌의 경기당 평균이다.
@immutable
class LegendPlayer {
  final String id;
  final String name;
  final PlayerLine line;

  /// 지금 구단 id(팀 로고를 찾는 데 쓴다). 옛 이름은 [teamName]에 있다.
  final String teamId;

  /// 1990 / 2000 / 2010 / 2020.
  final int era;

  /// 기록을 가져온 시즌("2005-2006")과 그때의 팀 이름("부산기아").
  final String season;
  final String teamName;

  /// 앱에 넣어 둔 얼굴 사진이 있는가. 없으면 이름 첫 글자를 보여준다.
  final bool hasPhoto;

  final int games;
  final double mpg;
  final double ppg;
  final double rpg;
  final double apg;
  final double spg;
  final double bpg;

  const LegendPlayer({
    required this.id,
    required this.name,
    required this.line,
    required this.teamId,
    required this.era,
    required this.season,
    required this.teamName,
    this.hasPhoto = false,
    required this.games,
    required this.mpg,
    required this.ppg,
    required this.rpg,
    required this.apg,
    required this.spg,
    required this.bpg,
  });

  static LegendPlayer? fromMap(Map<dynamic, dynamic> row) {
    final line = PlayerLine.parse(row['position'] as String?);
    final id = row['id'] as String?;
    if (line == null || id == null) return null;
    double d(String key) => (row[key] as num?)?.toDouble() ?? 0;
    return LegendPlayer(
      id: id,
      name: row['name'] as String? ?? '',
      line: line,
      teamId: row['teamId'] as String? ?? '',
      era: (row['era'] as num?)?.toInt() ?? 0,
      season: row['season'] as String? ?? '',
      teamName: row['teamName'] as String? ?? '',
      hasPhoto: row['hasPhoto'] == true,
      games: (row['games'] as num?)?.toInt() ?? 0,
      mpg: d('mpg'),
      ppg: d('ppg'),
      rpg: d('rpg'),
      apg: d('apg'),
      spg: d('spg'),
      bpg: d('bpg'),
    );
  }

  /// 앱에 넣어 둔 얼굴 사진. 없으면 null.
  String? get photoAsset => hasPhoto ? 'assets/game/photos/$id.jpg' : null;

  /// 같은 구단을 하나로 묶는 열쇠. KBL이 "서울SK"와 "서울 SK"를 섞어 쓴다.
  String get teamKey => teamKeyOf(teamName);

  /// 화면에 쓰는 그때 그 팀 이름("대구 동양").
  String get teamLabel => teamLabelOf(teamName);

  /// "2000년대", 화면 뱃지에 쓴다.
  String get eraLabel => '$era년대';

  /// 기록 한 줄: "22.6점 11.9리바 4.4어시".
  String get statLine =>
      '${ppg.toStringAsFixed(1)}점 ${rpg.toStringAsFixed(1)}리바 '
      '${apg.toStringAsFixed(1)}어시';

  /// 경기에 미친 영향력. 실제 경기당 기록만으로 구한다.
  ///
  /// 득점에 리바운드·어시스트·스틸·블록을 얹는 흔한 효율 계산이다. 숫자를
  /// 지어내지 않고 KBL 공식 기록만 쓴다.
  double get impact => ppg + rpg * 1.2 + apg * 1.5 + spg * 2 + bpg * 2;
}

/// 팀 이름을 묶는 열쇠. 띄어쓰기를 떼어 "서울SK"와 "서울 SK"를 같게 본다.
String teamKeyOf(String name) => name.replaceAll(' ', '');

/// KBL이 주는 이름("대구동양")에 연고지를 떼어 띄어 쓴다("대구 동양").
String teamLabelOf(String name) {
  final key = teamKeyOf(name);
  for (final city in _cities) {
    if (key.length > city.length && key.startsWith(city)) {
      return '$city ${key.substring(city.length)}';
    }
  }
  return key;
}

/// KBL 역대 연고지.
const _cities = [
  '서울',
  '부산',
  '대구',
  '인천',
  '광주',
  '대전',
  '울산',
  '수원',
  '고양',
  '창원',
  '전주',
  '원주',
  '안양',
  '청주',
  '여수',
  '천안',
  '경남',
];

/// 라운드마다 뽑히는 조건: 그때 그 구단, 그 시대.
///
/// 지금 구단이 아니라 그 시절 이름으로 묶는다. 1990년대에 고양 소노는 없었다
/// (대구 동양 오리온스였다). 같은 구단이라도 이름이 바뀌면 다른 조건이다.
@immutable
class RoundCondition {
  /// 띄어쓰기를 뗀 그때 그 팀 이름("대구동양"). 같고 다름을 이걸로 가린다.
  final String teamKey;

  final int era;

  /// 지금 구단 id. 이름이 그대로인 구단만 로고를 보여주는 데 쓴다.
  final String teamId;

  const RoundCondition({
    required this.teamKey,
    required this.era,
    required this.teamId,
  });

  /// 화면에 쓰는 이름("대구 동양").
  String get teamName => teamLabelOf(teamKey);

  String get eraLabel => '$era년대';

  @override
  bool operator ==(Object other) =>
      other is RoundCondition && other.teamKey == teamKey && other.era == era;

  @override
  int get hashCode => Object.hash(teamKey, era);
}

/// 결과 화면에 보여줄 승수와 그 근거.
@immutable
class LineupResult {
  /// 0~54.
  final int wins;

  /// 다섯 명의 전력 합(0~100으로 환산).
  final double powerScore;

  /// 제자리에 섰는지(0~100).
  final double fitScore;

  /// 같은 구단·같은 시대를 함께한 조합(0~100).
  final double synergyScore;

  /// 다섯 명의 경기당 기록을 더한 값. 이 라인업이 한 경기에 쌓는 기록이다.
  final double ppg;
  final double rpg;
  final double apg;
  final double spg;
  final double bpg;

  /// 무작위로 만든 라인업 [rankPool]팀과 견준 순위(1위가 가장 좋다).
  final int rank;
  final int rankPool;

  const LineupResult({
    required this.wins,
    required this.powerScore,
    required this.fitScore,
    required this.synergyScore,
    this.ppg = 0,
    this.rpg = 0,
    this.apg = 0,
    this.spg = 0,
    this.bpg = 0,
    this.rank = 0,
    this.rankPool = 0,
  });

  LineupResult withRank({required int rank, required int rankPool}) =>
      LineupResult(
        wins: wins,
        powerScore: powerScore,
        fitScore: fitScore,
        synergyScore: synergyScore,
        ppg: ppg,
        rpg: rpg,
        apg: apg,
        spg: spg,
        bpg: bpg,
        rank: rank,
        rankPool: rankPool,
      );

  int get losses => 54 - wins;
  bool get isPerfect => wins >= 54;

  /// 상위 몇 %인가. 순위를 매기지 않았으면 null이다.
  double? get topPercent =>
      rankPool <= 0 ? null : (rank / rankPool * 100).clamp(0.1, 100.0);

  String get headline => isPerfect ? '54승 0패 달성!' : '$wins승 $losses패';
}
