import '../../data/models/player_season_stats.dart';

/// 기록의 성격. 순위표 위에 무엇을 보여주는지 적는 데만 쓴다.
///
/// 출전 경기 수나 시도 횟수로 선수를 거르지 않는다. 네이버 스포츠 KBL
/// 선수 기록이 한 경기만 뛴 선수까지 모두 줄 세우기 때문이다(2025-26 시즌
/// 179명 전원, 1경기 출전 선수 포함). 리그마다 기준을 따로 만들면 시즌 초에
/// 한 팀 선수만 남는 것 같은 일이 생긴다.
enum RankingKind {
  /// 경기당 평균(득점·리바운드 등).
  perGame,

  /// 시즌 성공률(%).
  rate,

  /// 시즌 누적(더블더블, 한 경기 최다 득점 등).
  total,
}

/// 순위표 한 부문.
class RankingCategory {
  final String label;

  /// 값 뒤에 붙이는 단위(점, 개, %, 분, 경기, 회).
  final String unit;

  /// 그 선수의 값. 리그가 이 기록을 주지 않으면 null.
  final double? Function(PlayerSeasonStats) value;
  final RankingKind kind;
  final int decimals;

  const RankingCategory(
    this.label,
    this.unit,
    this.value, {
    this.kind = RankingKind.perGame,
    this.decimals = 1,
  });

  String format(double v) => v.toStringAsFixed(decimals);
}

double? _points(PlayerSeasonStats s) => s.points;
double? _rebounds(PlayerSeasonStats s) => s.reb;
double? _assists(PlayerSeasonStats s) => s.ast;
double? _steals(PlayerSeasonStats s) => s.stl;
double? _blocks(PlayerSeasonStats s) => s.blk;
double? _threesMade(PlayerSeasonStats s) => s.tpm;
double? _fgPct(PlayerSeasonStats s) => s.fga == 0 ? null : s.fgPct * 100;
double? _tpPct(PlayerSeasonStats s) => s.tpa == 0 ? null : s.tpPct * 100;
double? _ftPct(PlayerSeasonStats s) => s.fta == 0 ? null : s.ftPct * 100;
double? _fgMade(PlayerSeasonStats s) => s.fgm;
double? _ftMade(PlayerSeasonStats s) => s.ftm;
double? _offReb(PlayerSeasonStats s) => s.hasReboundSplit ? s.oreb : null;
double? _defReb(PlayerSeasonStats s) => s.hasReboundSplit ? s.dreb : null;
double? _doubleDoubles(PlayerSeasonStats s) => s.doubleDoubles?.toDouble();
double? _tripleDoubles(PlayerSeasonStats s) => s.tripleDoubles?.toDouble();
double? _gameHigh(PlayerSeasonStats s) => s.gameHigh?.toDouble();
double? _minutes(PlayerSeasonStats s) => s.minutes;
double? _games(PlayerSeasonStats s) => s.gamesPlayed.toDouble();
double? _turnovers(PlayerSeasonStats s) => s.tov;
double? _fouls(PlayerSeasonStats s) => s.pf;

/// 네이버 스포츠 KBL 선수 기록과 같은 부문, 같은 순서.
const rankingCategories = <RankingCategory>[
  RankingCategory('득점', '점', _points),
  RankingCategory('리바운드', '개', _rebounds),
  RankingCategory('어시스트', '개', _assists),
  RankingCategory('스틸', '개', _steals),
  RankingCategory('블록슛', '개', _blocks),
  RankingCategory('야투 성공', '개', _fgMade),
  RankingCategory('야투 성공률', '%', _fgPct, kind: RankingKind.rate),
  RankingCategory('3점슛 성공', '개', _threesMade),
  RankingCategory('3점슛 성공률', '%', _tpPct, kind: RankingKind.rate),
  RankingCategory('자유투 성공', '개', _ftMade),
  RankingCategory('자유투 성공률', '%', _ftPct, kind: RankingKind.rate),
  RankingCategory('공격 리바운드', '개', _offReb),
  RankingCategory('수비 리바운드', '개', _defReb),
  RankingCategory('턴오버', '개', _turnovers),
  RankingCategory('파울', '개', _fouls),
  RankingCategory('출전 시간', '분', _minutes),
  RankingCategory(
    '출전 경기',
    '경기',
    _games,
    kind: RankingKind.total,
    decimals: 0,
  ),
  // 아래 셋은 KBL 기록에 없어 화면에서 저절로 빠진다(리그가 주면 그때 보인다).
  RankingCategory(
    '더블더블',
    '회',
    _doubleDoubles,
    kind: RankingKind.total,
    decimals: 0,
  ),
  RankingCategory(
    '트리플더블',
    '회',
    _tripleDoubles,
    kind: RankingKind.total,
    decimals: 0,
  ),
  RankingCategory(
    '한 경기 최다 득점',
    '점',
    _gameHigh,
    kind: RankingKind.total,
    decimals: 0,
  ),
];

/// 순위표 위에 붙이는 설명. 네이버 스포츠처럼 무엇을 줄 세운 값인지만 적는다.
String rankingNote(RankingCategory category) => switch (category.kind) {
  RankingKind.perGame => '경기당 평균',
  RankingKind.rate => '시즌 성공률',
  RankingKind.total =>
    category.label == '한 경기 최다 득점' ? '정규시즌 한 경기 기록' : '시즌 누적',
};

/// 순위표 한 줄.
class RankedRow {
  /// 공동 순위면 같은 숫자(1, 2, 2, 4).
  final int rank;
  final PlayerSeasonStats stats;
  final double value;

  const RankedRow(this.rank, this.stats, this.value);
}

/// 이 리그 데이터에 해당 기록이 있는지. 전부 없거나 0이면 부문을 숨긴다.
bool isCategoryAvailable(
  List<PlayerSeasonStats> all,
  RankingCategory category,
) {
  return all.any((s) {
    final v = category.value(s);
    return v != null && v > 0;
  });
}

/// 기록이 있는 선수를 값 내림차순으로 줄 세운다.
///
/// 출전 경기 수로 거르지 않는다(네이버 스포츠 KBL 선수 기록과 같다).
/// 값이 정확히 같을 때만 공동 순위이고, 그다음 순위는 건너뛴다(1, 1, 3).
List<RankedRow> rankPlayers(
  List<PlayerSeasonStats> all,
  RankingCategory category, {
  int limit = 50,
}) {
  final rows = <(PlayerSeasonStats, double)>[];
  for (final s in all) {
    if (s.gamesPlayed <= 0) continue;
    final v = category.value(s);
    if (v == null) continue;
    rows.add((s, v));
  }
  rows.sort((a, b) => b.$2.compareTo(a.$2));

  final result = <RankedRow>[];
  for (var i = 0; i < rows.length && i < limit; i++) {
    final (stats, value) = rows[i];
    final tiedWithPrevious = i > 0 && rows[i - 1].$2 == value;
    final rank = tiedWithPrevious ? result[i - 1].rank : i + 1;
    result.add(RankedRow(rank, stats, value));
  }
  return result;
}
