import 'package:flutter/foundation.dart';

/// 팀의 시즌 평균 기록(경기당). 팀 순위 화면의 상세 스탯 표에 쓰인다.
@immutable
class TeamSeasonStats {
  final String teamId;
  final double pointsFor; // 득점
  final double pointsAgainst; // 실점
  final double rebounds;
  final double assists;
  final double steals;
  final double blocks;
  final double fgm;
  final double fga;
  final double tpm;
  final double tpa;
  final double ftm;
  final double fta;
  final double oreb;
  final double dreb;
  final double tov;
  final double pf;

  const TeamSeasonStats({
    required this.teamId,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.rebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    required this.fgm,
    required this.fga,
    required this.tpm,
    required this.tpa,
    required this.ftm,
    required this.fta,
    required this.oreb,
    required this.dreb,
    required this.tov,
    required this.pf,
  });

  double get fgPct => fga == 0 ? 0 : fgm / fga;
  double get tpPct => tpa == 0 ? 0 : tpm / tpa;
  double get ftPct => fta == 0 ? 0 : ftm / fta;
}
