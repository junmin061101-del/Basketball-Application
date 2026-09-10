import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/data/models/player.dart';
import 'package:basket_it/data/models/player_bio.dart';
import 'package:basket_it/data/models/player_game_stats.dart';
import 'package:basket_it/data/models/player_season_stats.dart';
import 'package:basket_it/data/models/team.dart';
import 'package:basket_it/data/models/team_season_stats.dart';
import 'package:basket_it/data/models/team_standing.dart';
import 'package:basket_it/data/repositories/game_repository.dart';
import 'package:basket_it/data/repositories/player_repository.dart';
import 'package:basket_it/data/repositories/team_repository.dart';

/// 위젯 테스트용 저장소. 네트워크 없이 넘겨준 값만 돌려준다.
class FakeTeamRepository implements TeamRepository {
  final List<Team> teams;

  const FakeTeamRepository([this.teams = const []]);

  @override
  Future<List<Team>> getTeams() async => teams;

  @override
  Future<Team?> getTeamById(String id) async {
    for (final team in teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  @override
  Future<List<TeamStanding>> getStandings() async => const [];

  @override
  Future<List<TeamSeasonStats>> getTeamSeasonStats() async => const [];
}

class FakePlayerRepository implements PlayerRepository {
  final List<Player> players;

  const FakePlayerRepository([this.players = const []]);

  @override
  Future<List<Player>> getPlayers() async => players;

  @override
  Future<Player?> getPlayerById(String id) async {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  @override
  Future<List<Player>> getPlayersByTeam(String teamId) async =>
      players.where((p) => p.teamId == teamId).toList();

  @override
  Future<List<Player>> getPlayersSortedByFollowers() async => players;

  @override
  Future<List<Player>> searchPlayersByName(String query) async =>
      players.where((p) => p.matchesQuery(query)).toList();

  @override
  Future<PlayerBio> getPlayerBio(Player player) async =>
      const PlayerBio.unknown();

  @override
  Future<List<PlayerSeasonStats>> getSeasonStatsHistory(Player player) async =>
      const [];

  @override
  Future<List<PlayerSeasonStats>> getCurrentSeasonStatsForAllPlayers() async =>
      const [];
}

class FakeGameRepository implements GameRepository {
  final List<Game> games;

  const FakeGameRepository([this.games = const []]);

  @override
  Future<List<Game>> getGamesByDate(DateTime date) async => games
      .where(
        (g) =>
            g.date.year == date.year &&
            g.date.month == date.month &&
            g.date.day == date.day,
      )
      .toList();

  @override
  Future<List<Game>> getGamesInRange(DateTime from, DateTime to) async =>
      games;

  @override
  Future<List<PlayerGameStats>> getBoxScore(Game game) async => const [];
}
