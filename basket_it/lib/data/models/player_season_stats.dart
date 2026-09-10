import 'package:flutter/foundation.dart';

/// 선수의 한 시즌 평균 기록. 선수 상세 화면 필수 스펙(6단계)에서 요구하는
/// 전 항목을 담는다: 출전 경기 수/소속 팀/평균 출전 시간부터 코트 마진까지.
@immutable
class PlayerSeasonStats {
  final String playerId;
  final String season; // 예: "2025-26"
  final String teamId;

  /// 원본이 준 팀 이름. 지금은 없는 옛 구단처럼 [teamId]로 팀을 못 찾을 때
  /// 화면이 대신 쓴다.
  final String? teamName;
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

  /// 시즌 누적 더블더블·트리플더블 횟수와 정규시즌 한 경기 최다 득점.
  /// 리그가 주지 않으면 null이고, 해당 순위 부문은 화면에서 숨는다.
  final int? doubleDoubles;
  final int? tripleDoubles;
  final int? gameHigh;

  /// [oreb]/[dreb]가 실제로 나뉜 값인지. 총합만 아는 선수는 [dreb]에 총합이
  /// 들어 있어, 공격·수비 리바운드 순위에 넣으면 안 된다.
  final bool hasReboundSplit;

  const PlayerSeasonStats({
    required this.playerId,
    required this.season,
    required this.teamId,
    this.teamName,
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
    this.doubleDoubles,
    this.tripleDoubles,
    this.gameHigh,
    this.hasReboundSplit = true,
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
