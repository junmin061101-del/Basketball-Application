import 'package:flutter/foundation.dart';

/// 팀 순위표 한 줄(승/패 기록).
@immutable
class TeamStanding {
  final String teamId;
  final int wins;
  final int losses;

  /// 1위 팀과의 게임차.
  final double gamesBehind;

  const TeamStanding({
    required this.teamId,
    required this.wins,
    required this.losses,
    required this.gamesBehind,
  });

  int get gamesPlayed => wins + losses;
  double get winPct => gamesPlayed == 0 ? 0 : wins / gamesPlayed;
}
