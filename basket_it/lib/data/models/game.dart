import 'package:flutter/foundation.dart';

enum GameStatus { scheduled, live, finished }

/// KBL 경기 정보 (한 경기 = 두 팀의 대진).
@immutable
class Game {
  final String id;
  final DateTime date;
  final String homeTeamId;
  final String awayTeamId;
  final int homeScore;
  final int awayScore;
  final GameStatus status;

  /// 경기 시작(팁오프) 시각.
  final DateTime startTime;

  /// 진행 중일 때만 사용 (예: "3쿼터 07:12").
  final String? liveClock;

  const Game({
    required this.id,
    required this.date,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.startTime,
    this.liveClock,
  });

  /// 승부예측 마감: 경기 시작 1시간 전.
  DateTime get predictionDeadline =>
      startTime.subtract(const Duration(hours: 1));

  /// 아직 예측을 받을 수 있는지(예정 경기이고 마감 전).
  bool isPredictionOpen([DateTime? now]) =>
      status == GameStatus.scheduled &&
      (now ?? DateTime.now()).isBefore(predictionDeadline);

  bool involvesTeam(String teamId) =>
      homeTeamId == teamId || awayTeamId == teamId;

  @override
  bool operator ==(Object other) => other is Game && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
