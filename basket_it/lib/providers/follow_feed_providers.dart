import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/game.dart';
import '../data/models/news_article.dart';
import '../data/models/player.dart';
import '../data/models/player_game_stats.dart';
import 'game_providers.dart';
import 'news_providers.dart';

/// 팀·선수 화면과 홈 상단 경기 섹션이 쓰는 조회들.
///
/// 원본은 이미 있는 뉴스 피드와 경기 Repository를 그대로 쓰고, 여기서는
/// "이 팀의", "이 선수의", "오늘 내 팀의"로 좁히기만 한다.

/// 팀/선수 화면에서 훑어볼 기간. 최근 전적과 다음 경기를 함께 담는다.
const _pastWindow = Duration(days: 21);
const _futureWindow = Duration(days: 21);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 오늘 열리는 모든 경기.
final todayGamesProvider = FutureProvider<List<Game>>((ref) {
  return ref.watch(gameRepositoryProvider).getGamesByDate(DateTime.now());
});

/// 한 팀의 최근·예정 경기를 시간순으로.
final teamGamesProvider = FutureProvider.family<List<Game>, String>((
  ref,
  teamId,
) async {
  final today = _dateOnly(DateTime.now());
  final games = await ref
      .watch(gameRepositoryProvider)
      .getGamesInRange(today.subtract(_pastWindow), today.add(_futureWindow));
  return games.where((g) => g.involvesTeam(teamId)).toList();
});

/// 한 팀의 다음 경기(아직 안 끝난 것 중 가장 이른 것). 없으면 null.
final nextGameProvider = FutureProvider.family<Game?, String>((
  ref,
  teamId,
) async {
  final games = await ref.watch(teamGamesProvider(teamId).future);
  for (final game in games) {
    if (game.status != GameStatus.finished) return game;
  }
  return null;
});

/// 한 팀의 최근 결과(최신순). [limit]개까지.
final recentResultsProvider =
    FutureProvider.family<List<Game>, ({String teamId, int limit})>((
      ref,
      arg,
    ) async {
      final games = await ref.watch(teamGamesProvider(arg.teamId).future);
      final finished = games
          .where((g) => g.status == GameStatus.finished)
          .toList()
          .reversed
          .toList();
      return finished.take(arg.limit).toList();
    });

/// 두 팀의 시즌 상대 전적(끝난 경기만).
final headToHeadProvider =
    FutureProvider.family<List<Game>, ({String teamId, String opponentId})>((
      ref,
      arg,
    ) async {
      final games = await ref.watch(teamGamesProvider(arg.teamId).future);
      return games
          .where(
            (g) =>
                g.status == GameStatus.finished &&
                g.involvesTeam(arg.opponentId),
          )
          .toList()
          .reversed
          .toList();
    });

/// 팀이 이겼는지. 무승부는 없다고 본다.
bool teamWon(Game game, String teamId) {
  final isHome = game.homeTeamId == teamId;
  return isHome
      ? game.homeScore > game.awayScore
      : game.awayScore > game.homeScore;
}

/// 최근 N경기 요약(승-패, 평균 득점·실점).
class RecentForm {
  final int wins;
  final int losses;
  final double pointsFor;
  final double pointsAgainst;

  const RecentForm({
    required this.wins,
    required this.losses,
    required this.pointsFor,
    required this.pointsAgainst,
  });

  int get played => wins + losses;
  String get record => '$wins승 $losses패';

  static RecentForm from(List<Game> games, String teamId) {
    if (games.isEmpty) {
      return const RecentForm(
        wins: 0,
        losses: 0,
        pointsFor: 0,
        pointsAgainst: 0,
      );
    }
    var wins = 0;
    var scored = 0;
    var allowed = 0;
    for (final game in games) {
      final isHome = game.homeTeamId == teamId;
      scored += isHome ? game.homeScore : game.awayScore;
      allowed += isHome ? game.awayScore : game.homeScore;
      if (teamWon(game, teamId)) wins++;
    }
    return RecentForm(
      wins: wins,
      losses: games.length - wins,
      pointsFor: scored / games.length,
      pointsAgainst: allowed / games.length,
    );
  }
}

/// 최근 5경기 폼.
final recentFormProvider = FutureProvider.family<RecentForm, String>((
  ref,
  teamId,
) async {
  final games = await ref.watch(
    recentResultsProvider((teamId: teamId, limit: 5)).future,
  );
  return RecentForm.from(games, teamId);
});

/// 선수 상세의 "최근 경기 기록": 소속팀의 끝난 경기에서 그 선수가 뛴 경기만,
/// 최신순으로 [_recentPlayerGames]경기.
///
/// 비시즌에도 지난 시즌 마지막 경기들이 보이도록 1년 넘게 거슬러 본다(지난
/// 시즌 박스스코어도 보관돼 있다). 결장한 경기는 건너뛰되, 박스스코어를 너무
/// 많이 받지 않도록 [_recentPlayerLookups]경기까지만 확인한다.
final playerRecentStatsProvider =
    FutureProvider.family<List<({Game game, PlayerGameStats stats})>, Player>((
      ref,
      player,
    ) async {
      final now = DateTime.now();
      final repository = ref.watch(gameRepositoryProvider);
      final games = await repository.getGamesInRange(
        now.subtract(const Duration(days: 400)),
        now,
      );
      final finished =
          games
              .where(
                (g) =>
                    g.status == GameStatus.finished &&
                    g.involvesTeam(player.teamId),
              )
              .toList()
            ..sort((a, b) => b.startTime.compareTo(a.startTime));

      final rows = <({Game game, PlayerGameStats stats})>[];
      for (final game in finished.take(_recentPlayerLookups)) {
        if (rows.length >= _recentPlayerGames) break;
        final boxScore = await repository.getBoxScore(game);
        for (final line in boxScore) {
          if (line.playerId == player.id) {
            rows.add((game: game, stats: line));
            break;
          }
        }
      }
      return rows;
    });

const _recentPlayerGames = 5;
const _recentPlayerLookups = 12;

/// 한 팀에 관한 기사만 추린다.
final teamNewsProvider = FutureProvider.family<List<NewsArticle>, String>((
  ref,
  teamId,
) async {
  final feed = await ref.watch(allNewsProvider.future);
  return feed.where((a) => a.relatedTeamId == teamId).toList();
});

/// 한 선수에 관한 기사만 추린다.
///
/// 수집 단계에서 기사에 선수를 붙이지는 않으므로, 제목·본문에 이름이
/// 있는지로 고른다. 이름이 없으면 소속팀 기사를 대신 보여주는 게 아니라
/// 빈 목록을 준다(엉뚱한 기사를 그 선수 것처럼 보이게 하지 않기 위해).
final playerNewsProvider = FutureProvider.family<List<NewsArticle>, Player>((
  ref,
  player,
) async {
  // 전체 묶음은 두 리그를 합쳐 40건에서 잘리므로, 지금 리그 뉴스도 함께 본다.
  final repository = ref.watch(newsRepositoryProvider);
  final lists = await Future.wait([
    ref.watch(allNewsProvider.future),
    repository
        .getNews(category: ref.watch(newsCategoryProvider))
        .catchError((_) => <NewsArticle>[]),
  ]);
  final byId = <String, NewsArticle>{};
  for (final article in lists.expand((l) => l)) {
    if (article.title.contains(player.name) ||
        (article.summary?.contains(player.name) ?? false)) {
      byId.putIfAbsent(article.id, () => article);
    }
  }
  return byId.values.toList()
    ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
});
