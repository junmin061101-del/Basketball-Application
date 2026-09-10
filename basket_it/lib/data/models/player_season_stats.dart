import 'package:flutter/foundation.dart';

/// 선수의 한 시즌 평균 기록. 선수 상세 화면 필수 스펙(6단계)에서 요구하는
/// 전 항목을 담는다: 출전 경기 수/소속 팀/평균 출전 시간부터 코트 마진까지.
@immutable
class PlayerSeasonStats {
  final String playerId;
  final String season; // 예: "2025-26"
  final String teamId;
  final int gamesPlayed;
  final double minutes;
  final double points;
  final double fgm;
  final double fga;
  final double tpm;
  final double tpa;
  final double ftm;
  final double fta;
  final double oreb;
  final double dreb;
  final double ast;
  final double tov;
  final double stl;
  final double blk;
  final double pf;
  final double plusMinus;

  const PlayerSeasonStats({
    required this.playerId,
    required this.season,
    required this.teamId,
    required this.gamesPlayed,
    required this.minutes,
    required this.points,
    required this.fgm,
    required this.fga,
    required this.tpm,
    required this.tpa,
    required this.ftm,
    required this.fta,
    required this.oreb,
    required this.dreb,
    required this.ast,
    required this.tov,
    required this.stl,
    required this.blk,
    required this.pf,
    required this.plusMinus,
  });

  /// 한 시즌에 여러 팀에서 뛴 선수의 합계 줄을 나타내는 teamId.
  static const totalsTeamId = '';

  /// 여러 팀 기록을 합친 줄인지.
  bool get isTotals => teamId == totalsTeamId;

  double get reb => oreb + dreb;
  double get fgPct => fga == 0 ? 0 : fgm / fga;
  double get tpPct => tpa == 0 ? 0 : tpm / tpa;
  double get ftPct => fta == 0 ? 0 : ftm / fta;
}
