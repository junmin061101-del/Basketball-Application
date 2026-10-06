import 'package:flutter/foundation.dart';

import '../../../data/player_photos.dart';

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

/// 지금 KBL에서 뛰는 선수. 기록은 제대로 치른 가장 최근 시즌의 경기당 평균이다.
@immutable
class GamePlayer {
  final String id;
  final String name;
  final PlayerLine line;

  /// 지금 소속 구단.
  final String teamId;
  final String teamName;

  /// 기록을 가져온 시즌("2025-2026").
  final String season;

  final int games;
  final double mpg;
  final double ppg;
  final double rpg;
  final double apg;
  final double spg;
  final double bpg;

  const GamePlayer({
    required this.id,
    required this.name,
    required this.line,
    required this.teamId,
    required this.teamName,
    required this.season,
    required this.games,
    required this.mpg,
    required this.ppg,
    required this.rpg,
    required this.apg,
    required this.spg,
    required this.bpg,
  });

  static GamePlayer? fromMap(Map<dynamic, dynamic> row) {
    final line = PlayerLine.parse(row['position'] as String?);
    final id = row['id'] as String?;
    if (line == null || id == null) return null;
    double d(String key) => (row[key] as num?)?.toDouble() ?? 0;
    return GamePlayer(
      id: id,
      name: row['name'] as String? ?? '',
      line: line,
      teamId: row['teamId'] as String? ?? '',
      teamName: row['teamName'] as String? ?? '',
      season: row['season'] as String? ?? '',
      games: (row['games'] as num?)?.toInt() ?? 0,
      mpg: d('mpg'),
      ppg: d('ppg'),
      rpg: d('rpg'),
      apg: d('apg'),
      spg: d('spg'),
      bpg: d('bpg'),
    );
  }

  /// 앱에 넣어 둔 얼굴 사진. 없으면 null(이름 첫 글자를 보여준다).
  String? get photoAsset => playerPhotoAsset(id);

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

/// 라운드마다 룰렛이 뽑는 조건: 어느 구단에서 고를지.
@immutable
class RoundCondition {
  final String teamId;
  final String teamName;

  const RoundCondition({required this.teamId, required this.teamName});

  @override
  bool operator ==(Object other) =>
      other is RoundCondition && other.teamId == teamId;

  @override
  int get hashCode => teamId.hashCode;
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

  /// 다섯 명의 경기당 기록을 더한 값. 이 라인업이 한 경기에 쌓는 기록이다.
  final double ppg;
  final double rpg;
  final double apg;
  final double spg;
  final double bpg;

  /// 같은 규칙으로 만들어 본 라인업 [rankPool]팀과 견준 순위(1위가 가장 좋다).
  final int rank;
  final int rankPool;

  const LineupResult({
    required this.wins,
    required this.powerScore,
    required this.fitScore,
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
