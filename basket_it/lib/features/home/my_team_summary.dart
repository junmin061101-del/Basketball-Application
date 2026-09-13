import 'package:flutter/foundation.dart';

import '../../data/models/game.dart';
import '../../data/models/team_standing.dart';

/// 순위표에서 내 팀 바로 위·아래 팀.
@immutable
class RankNeighbor {
  final String teamId;
  final int rank;

  /// 내 팀과의 게임차(항상 0 이상).
  final double gamesBehind;

  const RankNeighbor({
    required this.teamId,
    required this.rank,
    required this.gamesBehind,
  });
}

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

  /// 바로 위 순위 팀(1위면 null)과 바로 아래 순위 팀(꼴찌면 null).
  final RankNeighbor? above;
  final RankNeighbor? below;

  /// 최근 5경기 결과. 오래된 경기부터, true가 승리.
  final List<bool> lastFive;

  /// 연승이면 양수, 연패면 음수. 경기가 없으면 0.
  final int streak;

  /// 크게 보여줄 경기: 오늘 경기가 있으면 그 경기, 없으면 가장 최근에 끝난 경기.
  final Game? featuredGame;

  /// [featuredGame]이 오늘 경기인지.
  final bool featuredIsToday;

  /// 다음 경기(아직 시작 전). [featuredGame]은 빼고 찾는다.
  final Game? nextGame;

  const MyTeamSummary({
    required this.teamId,
    required this.rank,
    required this.scope,
    required this.wins,
    required this.losses,
    required this.above,
    required this.below,
    required this.lastFive,
    required this.streak,
    required this.featuredGame,
    required this.featuredIsToday,
    required this.nextGame,
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

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _won(Game game, String teamId) => game.homeTeamId == teamId
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
    RankNeighbor? above;
    RankNeighbor? below;
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
      if (index > 0) {
        final other = rows[index - 1];
        above = RankNeighbor(
          teamId: other.teamId,
          rank: index,
          gamesBehind: gamesBetween(other, mine).abs(),
        );
      }
      if (index < rows.length - 1) {
        final other = rows[index + 1];
        below = RankNeighbor(
          teamId: other.teamId,
          rank: index + 2,
          gamesBehind: gamesBetween(mine, other).abs(),
        );
      }
      break;
    }

    // --- 경기 ---
    final mineGames = games.where((g) => g.involvesTeam(teamId)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final finished = mineGames
        .where((g) => g.status == GameStatus.finished)
        .toList();

    final recent = finished.reversed.take(5).toList().reversed.toList();
    final lastFive = [for (final g in recent) _won(g, teamId)];

    // 연승·연패: 가장 최근 경기부터 같은 결과가 이어진 만큼. 시즌을 건너뛰지
    // 않도록 경기 사이가 120일 넘게 벌어지면 끊는다.
    var streak = 0;
    for (var i = finished.length - 1; i >= 0; i--) {
      final won = _won(finished[i], teamId);
      if (streak != 0 && won != streak > 0) break;
      if (i < finished.length - 1 &&
          finished[i + 1].startTime.difference(finished[i].startTime).inDays >
              120) {
        break;
      }
      streak += won ? 1 : -1;
    }

    final today = _day(now);
    final todayGames =
        mineGames.where((g) => _day(g.startTime) == today).toList()
          ..sort((a, b) => _todayPriority(a).compareTo(_todayPriority(b)));
    final featured = todayGames.isNotEmpty
        ? todayGames.first
        : (finished.isEmpty ? null : finished.last);

    // 크게 보여주는 경기는 건너뛰고 그 다음 예정 경기를 찾는다.
    Game? next;
    for (final g in mineGames) {
      if (g.id == featured?.id) continue;
      if (g.status == GameStatus.scheduled && g.startTime.isAfter(now)) {
        next = g;
        break;
      }
    }

    return MyTeamSummary(
      teamId: teamId,
      rank: rank,
      scope: scope,
      wins: wins,
      losses: losses,
      above: above,
      below: below,
      lastFive: lastFive,
      streak: streak,
      featuredGame: featured,
      featuredIsToday: todayGames.isNotEmpty,
      nextGame: next,
    );
  }

  /// 오늘 경기가 여럿이면(더블헤더는 없지만 대비) 진행중 → 예정 → 종료.
  static int _todayPriority(Game game) => switch (game.status) {
    GameStatus.live => 0,
    GameStatus.scheduled => 1,
    GameStatus.finished => 2,
  };
}

/// [ahead]가 [behind]보다 몇 게임 앞서는지. ((승 차) + (패 차)) / 2.
double gamesBetween(TeamStanding ahead, TeamStanding behind) =>
    ((ahead.wins - behind.wins) + (behind.losses - ahead.losses)) / 2;

/// 게임차 표기. 6 → "6게임차", 0.5 → "0.5게임차", 0 → "승차 없음".
String gamesBehindLabel(double games) {
  if (games == 0) return '승차 없음';
  final text = games == games.roundToDouble()
      ? games.toInt().toString()
      : games.toStringAsFixed(1);
  return '$text게임차';
}

/// 이름 뒤에 붙는 조사 "와/과". 받침이 있으면 "과".
///
/// 한글은 마지막 글자의 받침으로, 영문 약어는 읽는 소리로 정한다
/// (LG → 엘지와, NC → 엔씨와, SSG → 에스에스지와). L·M·N·R로 끝나면 받침이 있다.
String withWaGwa(String name) {
  if (name.isEmpty) return name;
  final last = name.runes.last;
  bool hasBatchim;
  if (last >= 0xAC00 && last <= 0xD7A3) {
    hasBatchim = (last - 0xAC00) % 28 != 0;
  } else {
    final ch = String.fromCharCode(last).toUpperCase();
    hasBatchim = 'LMNR013678'.contains(ch);
  }
  return '$name${hasBatchim ? '과' : '와'}';
}
