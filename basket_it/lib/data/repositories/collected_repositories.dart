import '../models/game.dart';
import '../models/player.dart';
import '../models/player_game_stats.dart';
import '../models/player_season_stats.dart';
import '../models/team.dart';
import '../models/team_season_stats.dart';
import '../models/team_standing.dart';
import 'game_repository.dart';
import 'league_data_source.dart';
import 'player_repository.dart';
import 'team_repository.dart';

/// 수집기가 올려둔 정적 JSON에서 읽는 팀 정보. NBA·KBL 공용.
class CollectedTeamRepository implements TeamRepository {
  final LeagueDataSource _source;

  CollectedTeamRepository(this._source);

  @override
  Future<List<Team>> getTeams() => _source.teams();

  @override
  Future<Team?> getTeamById(String id) async {
    final teams = await _source.teams();
    for (final team in teams) {
      if (team.id == id) return team;
    }
    return null;
  }

  @override
  Future<List<TeamStanding>> getStandings() => _source.standings();

  /// 수집기가 팀마다 모아 둔 시즌 평균. 실점은 수집기가 순위(NBA)나
  /// 경기 결과(KBL)에서 채운다.
  @override
  Future<List<TeamSeasonStats>> getTeamSeasonStats() => _source.teamStats();
}

/// 수집기가 올려둔 일정·결과를 읽는 경기 정보. NBA·KBL 공용.
class CollectedGameRepository implements GameRepository {
  final LeagueDataSource _source;

  CollectedGameRepository(this._source);

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Future<List<Game>> getGamesByDate(DateTime date) async {
    final target = _dateOnly(date);
    final games = await _source.games();
    return games.where((g) => _dateOnly(g.date) == target).toList();
  }

  @override
  Future<List<Game>> getGamesInRange(DateTime from, DateTime to) async {
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    final games = await _source.games();
    return games.where((g) {
      final day = _dateOnly(g.date);
      return !day.isBefore(start) && !day.isAfter(end);
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// 수집기가 끝난·진행 중 경기마다 받아둔 박스스코어. 예정 경기는 빈 목록.
  @override
  Future<List<PlayerGameStats>> getBoxScore(Game game) async {
    if (game.status == GameStatus.scheduled) return const [];
    return _source.boxScore(game.id);
  }
}

/// 수집기가 올려둔 선수 명단을 쓰는 선수 저장소의 공통 부분.
///
/// 명단·검색·이번 시즌 기록은 리그와 상관없이 같은 모양의 파일에서 읽는다.
/// 신상과 시즌별 기록은 리그마다 출처가 달라 하위 클래스가 정한다.
abstract class CollectedPlayerRepository implements PlayerRepository {
  final LeagueDataSource source;

  CollectedPlayerRepository(this.source);

  @override
  Future<List<Player>> getPlayers() => source.players();

  @override
  Future<Player?> getPlayerById(String id) async {
    final players = await source.players();
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  /// 팀 선수단. 기록·박스스코어에서만 합쳐 둔 로스터 밖 선수는 뺀다.
  @override
  Future<List<Player>> getPlayersByTeam(String teamId) async {
    final players = await source.players();
    final offRoster = await source.offRosterIds();
    return players
        .where((p) => p.teamId == teamId && !offRoster.contains(p.id))
        .toList();
  }

  /// 원본이 팔로워 수를 주지 않는다. 지어낸 인기순 대신 이름순으로 준다.
  @override
  Future<List<Player>> getPlayersSortedByFollowers() async {
    final players = [...await source.players()];
    players.sort((a, b) => a.name.compareTo(b.name));
    return players;
  }

  @override
  Future<List<Player>> searchPlayersByName(String query) async {
    if (query.trim().isEmpty) return getPlayers();
    final players = await source.players();
    // 한국어 이름과 영문 이름을 모두 받는다.
    return players.where((p) => p.matchesQuery(query)).toList();
  }

  /// 전 선수 이번 시즌 기록. 수집기가 한 번에 받아둔 것을 쓴다.
  ///
  /// 출전 수로 거르지 않고 전원을 준다. 순위 자격은 부문마다 다르다
  /// (경기당 기록은 출전 70%, 성공률은 누적 성공 개수, 더블더블은 제한 없음).
  /// 그 판단은 랭킹 화면의 부문 정의(ranking_categories.dart)가 한다.
  @override
  Future<List<PlayerSeasonStats>> getCurrentSeasonStatsForAllPlayers() {
    return source.leaders();
  }
}
