import '../../data/models/player_season_stats.dart';

/// 순위에 들어갈 자격을 따지는 방식.
enum RankingQualifier {
  /// 경기당 기록: 가장 많이 뛴 선수의 70% 이상 출전.
  perGame,

  /// 성공률: 시즌 누적 성공 개수 하한(NBA 공식 기준을 경기 수에 비례).
  fieldGoal,
  threePoint,
  freeThrow,

  /// 누적 기록(더블더블, 최다 득점 등): 제한 없음.
  none,
}

/// 순위표 한 부문.
class RankingCategory {
  final String label;

  /// 값 뒤에 붙이는 단위(점, 개, %, 분, 경기, 회).
  final String unit;

  /// 그 선수의 값. 리그가 이 기록을 주지 않으면 null.
  final double? Function(PlayerSeasonStats) value;
  final RankingQualifier qualifier;
  final int decimals;

  const RankingCategory(
    this.label,
    this.unit,
    this.value, {
    this.qualifier = RankingQualifier.perGame,
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

/// 네이버 스포츠 NBA 선수 순위와 같은 부문, 같은 순서.
const rankingCategories = <RankingCategory>[
  RankingCategory('득점', '점', _points),
  RankingCategory('리바운드', '개', _rebounds),
  RankingCategory('어시스트', '개', _assists),
  RankingCategory('스틸', '개', _steals),
  RankingCategory('블록', '개', _blocks),
  RankingCategory('3점슛 성공', '개', _threesMade),
  RankingCategory('야투율', '%', _fgPct, qualifier: RankingQualifier.fieldGoal),
  RankingCategory(
    '3점슛 성공률',
    '%',
    _tpPct,
    qualifier: RankingQualifier.threePoint,
  ),
  RankingCategory(
    '자유투 성공률',
    '%',
    _ftPct,
    qualifier: RankingQualifier.freeThrow,
  ),
  RankingCategory('야투 성공', '개', _fgMade),
  RankingCategory('자유투 성공', '개', _ftMade),
  RankingCategory('공격 리바운드', '개', _offReb),
  RankingCategory('수비 리바운드', '개', _defReb),
  RankingCategory(
    '더블더블',
    '회',
    _doubleDoubles,
    qualifier: RankingQualifier.none,
    decimals: 0,
  ),
  RankingCategory(
    '트리플더블',
    '회',
    _tripleDoubles,
    qualifier: RankingQualifier.none,
    decimals: 0,
  ),
  RankingCategory(
    '한 경기 최다 득점',
    '점',
    _gameHigh,
    qualifier: RankingQualifier.none,
    decimals: 0,
  ),
  RankingCategory('출전 시간', '분', _minutes),
  RankingCategory(
    '출전 경기',
    '경기',
    _games,
    qualifier: RankingQualifier.none,
    decimals: 0,
  ),
  RankingCategory('턴오버', '개', _turnovers),
  RankingCategory('파울', '개', _fouls),
];

/// 경기당 기록 순위에 들기 위한 최소 출전 비율(NBA 공식: 팀 경기의 70%).
const perGameQualifyingRatio = 0.7;

/// 성공률 순위에 들기 위한 팀 경기당 성공 개수.
///
/// NBA 공식 기준은 82경기 시즌에 야투 300개, 3점슛 82개, 자유투 125개
/// 성공이다. 시즌 중에는 치른 경기 수에 비례해 줄인다. 한두 번 던져 다
/// 넣은 선수가 100%로 1위에 오르지 않게 하려는 것이다.
const _madePerTeamGame = <RankingQualifier, double>{
  RankingQualifier.fieldGoal: 300 / 82,
  RankingQualifier.threePoint: 82 / 82,
  RankingQualifier.freeThrow: 125 / 82,
};

/// 한 순위표 안에서 공통으로 쓰는 기준값.
class RankingContext {
  /// 가장 많이 뛴 선수의 경기 수. 팀 경기 수 대신 쓴다.
  final int maxGames;

  const RankingContext(this.maxGames);

  factory RankingContext.of(List<PlayerSeasonStats> all) {
    var max = 0;
    for (final s in all) {
      if (s.gamesPlayed > max) max = s.gamesPlayed;
    }
    return RankingContext(max);
  }

  int get minGames => (maxGames * perGameQualifyingRatio).ceil();

  int minMade(RankingQualifier qualifier) =>
      (maxGames * (_madePerTeamGame[qualifier] ?? 0)).ceil();

  bool qualifies(PlayerSeasonStats s, RankingQualifier qualifier) {
    // 평균 × 경기 수로 시즌 누적 성공 개수를 되돌린다(평균이 반올림돼 와서 반올림).
    int total(double perGame) => (perGame * s.gamesPlayed).round();
    return switch (qualifier) {
      RankingQualifier.perGame => s.gamesPlayed >= minGames,
      RankingQualifier.fieldGoal => total(s.fgm) >= minMade(qualifier),
      RankingQualifier.threePoint => total(s.tpm) >= minMade(qualifier),
      RankingQualifier.freeThrow => total(s.ftm) >= minMade(qualifier),
      RankingQualifier.none => true,
    };
  }

  /// 순위표 위에 붙이는 기준 설명.
  String noteFor(RankingCategory category) => switch (category.qualifier) {
    RankingQualifier.perGame => '경기당 평균 · $minGames경기 이상 출전 선수',
    RankingQualifier.fieldGoal =>
      '시즌 야투 성공 ${minMade(category.qualifier)}개 이상 선수',
    RankingQualifier.threePoint =>
      '시즌 3점슛 성공 ${minMade(category.qualifier)}개 이상 선수',
    RankingQualifier.freeThrow =>
      '시즌 자유투 성공 ${minMade(category.qualifier)}개 이상 선수',
    RankingQualifier.none =>
      category.label == '한 경기 최다 득점' ? '정규시즌 한 경기 기록' : '시즌 누적',
  };
}

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

/// 자격을 갖춘 선수만 값 내림차순으로 줄 세운다.
///
/// 화면에 보이는 자릿수로 같으면 공동 순위다. 1.94와 1.86은 둘 다 1.9로
/// 보이는데 2위·3위로 나누면 이유를 알 수 없다.
List<RankedRow> rankPlayers(
  List<PlayerSeasonStats> all,
  RankingCategory category, {
  int limit = 30,
}) {
  final context = RankingContext.of(all);
  final rows = <(PlayerSeasonStats, double)>[];
  for (final s in all) {
    final v = category.value(s);
    if (v == null) continue;
    if (!context.qualifies(s, category.qualifier)) continue;
    rows.add((s, v));
  }
  rows.sort((a, b) => b.$2.compareTo(a.$2));

  final result = <RankedRow>[];
  for (var i = 0; i < rows.length && i < limit; i++) {
    final (stats, value) = rows[i];
    final tiedWithPrevious =
        i > 0 && category.format(rows[i - 1].$2) == category.format(value);
    final rank = tiedWithPrevious ? result[i - 1].rank : i + 1;
    result.add(RankedRow(rank, stats, value));
  }
  return result;
}
