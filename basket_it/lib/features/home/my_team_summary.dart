import 'package:flutter/material.dart' show DateUtils, immutable;

import '../../data/models/game.dart';
import '../../data/models/team_standing.dart';

/// 홈 "내 팀" 카드에 보여줄 값. 순위표와 경기 결과에서만 계산한다.
@immutable
class MyTeamSummary {
  final String teamId;

  /// 순위(1부터). 순위표에 없으면 null.
  final int? rank;

  /// 순위를 매긴 범위. NBA는 "동부"/"서부", KBL은 빈 문자열.
  final String scope;

  final int wins;
  final int losses;

  /// 순위표에서 내 팀 앞뒤로 다섯 줄(위·아래 끝이면 한쪽으로 몰린다). (순위, 줄).
  final List<(int, TeamStanding)> nearby;

  /// 연승이면 양수, 연패면 음수. 경기가 없으면 0.
  final int streak;

  /// 일정 다섯 경기, 날짜순: 최근에 끝난 경기 + 진행중·예정 경기(최대 3).
  /// 예정 경기가 모자라면(비시즌) 끝난 경기로 채운다.
  final List<Game> schedule;

  /// 오늘 경기(진행중 → 예정 → 종료 순으로 하나). 없으면 null. 홈 맨 위 중계 카드.
  final Game? todayGame;

  const MyTeamSummary({
    required this.teamId,
    required this.rank,
    required this.scope,
    required this.wins,
    required this.losses,
    required this.nearby,
    required this.streak,
    required this.schedule,
    required this.todayGame,
  });

  /// "동부 7위" / "7위". 순위가 없으면 null.
  String? get rankLabel =>
      rank == null ? null : (scope.isEmpty ? '$rank위' : '$scope $rank위');

  /// "3연승" / "3연패". 2경기 이상 이어질 때만.
  String? get streakLabel {
    if (streak >= 2) return '$streak연승';
    if (streak <= -2) return '${-streak}연패';
    return null;
  }

  static const _scopeNames = {'east': '동부', 'west': '서부'};

  /// [teamId]가 이 경기를 이겼는지(끝난 경기만 뜻이 있다).
  static bool won(Game game, String teamId) => game.homeTeamId == teamId
      ? game.homeScore > game.awayScore
      : game.awayScore > game.homeScore;

  /// [standings]는 리그 전체 순위표, [games]는 리그 경기(기간 무관)다.
  static MyTeamSummary build({
    required String teamId,
    required List<TeamStanding> standings,
    required List<Game> games,
    required DateTime now,
  }) {
    // --- 순위: 컨퍼런스(없으면 리그) 안에서 매긴다 ---
    int? rank;
    var scope = '';
    var wins = 0;
    var losses = 0;
    var nearby = const <(int, TeamStanding)>[];
    for (final group in groupStandings(standings)) {
      final rows = group.rows;
      final index = rows.indexWhere((s) => s.teamId == teamId);
      if (index < 0) continue;
      final mine = rows[index];
      // 개막 전처럼 아무도 경기를 안 했으면 순위는 의미가 없다.
      if (rows.every((s) => s.gamesPlayed == 0)) break;
      rank = index + 1;
      scope = _scopeNames[mine.conference] ?? '';
      wins = mine.wins;
      losses = mine.losses;
      final from = (index - 2).clamp(
        0,
        (rows.length - 5).clamp(0, rows.length),
      );
      nearby = [
        for (var i = from; i < rows.length && i < from + 5; i++)
          (i + 1, rows[i]),
      ];
      break;
    }

    // --- 경기 ---
    final mineGames = games.where((g) => g.involvesTeam(teamId)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final finished = mineGames
        .where((g) => g.status == GameStatus.finished)
        .toList();

    // 연승·연패: 가장 최근 경기부터 같은 결과가 이어진 만큼. 시즌을 건너뛰지
    // 않도록 경기 사이가 120일 넘게 벌어지면 끊는다.
    var streak = 0;
    for (var i = finished.length - 1; i >= 0; i--) {
      final w = won(finished[i], teamId);
      if (streak != 0 && w != streak > 0) break;
      if (i < finished.length - 1 &&
          finished[i + 1].startTime.difference(finished[i].startTime).inDays >
              120) {
        break;
      }
      streak += w ? 1 : -1;
    }

    final upcoming = mineGames
        .where(
          (g) =>
              g.status == GameStatus.live ||
              (g.status == GameStatus.scheduled && g.startTime.isAfter(now)),
        )
        .take(3)
        .toList();
    final past = finished.reversed.take(5 - upcoming.length).toList().reversed;

    final today = DateUtils.dateOnly(now);
    final todayGames =
        mineGames
            .where((g) => DateUtils.dateOnly(g.startTime) == today)
            .toList()
          ..sort((a, b) => _todayOrder(a).compareTo(_todayOrder(b)));

    return MyTeamSummary(
      teamId: teamId,
      rank: rank,
      scope: scope,
      wins: wins,
      losses: losses,
      nearby: nearby,
      streak: streak,
      schedule: [...past, ...upcoming],
      todayGame: todayGames.firstOrNull,
    );
  }

  static int _todayOrder(Game game) => switch (game.status) {
    GameStatus.live => 0,
    GameStatus.scheduled => 1,
    GameStatus.finished => 2,
  };
}
