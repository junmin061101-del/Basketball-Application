import 'package:flutter/foundation.dart';

/// 한 경기에서의 선수 기록(박스스코어 한 줄).
///
/// 필드 구성은 선수 상세 화면(4단계)의 시즌 스탯 표와 동일한 항목의
/// 단일 경기 버전이다 — 시즌 평균은 결국 이 값들의 누적/평균이 된다.
@immutable
class PlayerGameStats {
  final String playerId;
  final String gameId;
  final String teamId;

  final int minutes;
  final int points;
  final int fgm; // 필드골 성공
  final int fga; // 필드골 시도
  final int tpm; // 3점 성공
  final int tpa; // 3점 시도
  final int ftm; // 자유투 성공
  final int fta; // 자유투 시도
  final int oreb; // 공격 리바운드
  final int dreb; // 수비 리바운드
  final int ast;
  final int tov; // 턴오버
  final int stl;
  final int blk;
  final int pf; // 개인 파울
  final int plusMinus;

  const PlayerGameStats({
    required this.playerId,
    required this.gameId,
    required this.teamId,
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

  int get reb => oreb + dreb;
  double get fgPct => fga == 0 ? 0 : fgm / fga;
  double get tpPct => tpa == 0 ? 0 : tpm / tpa;
  double get ftPct => fta == 0 ? 0 : ftm / fta;
}
