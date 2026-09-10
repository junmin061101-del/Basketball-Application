import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/game.dart';
import '../models/player.dart';
import '../models/player_bio.dart';
import '../models/player_game_stats.dart';
import '../models/player_season_stats.dart';
import '../models/team.dart';
import '../models/team_season_stats.dart';
import '../models/team_standing.dart';
import 'game_repository.dart';
import 'nba_source.dart';
import 'player_repository.dart';
import 'team_repository.dart';

/// NBA 팀 정보. 수집기가 올려둔 정적 JSON을 읽는다.
class NbaTeamRepository implements TeamRepository {
  final NbaSource _source;

  NbaTeamRepository(this._source);

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

  /// ESPN에서 팀 시즌 평균까지는 모으지 않는다.
  /// 없는 값을 지어내지 않고 빈 목록을 준다. 화면은 빈 상태를 보여준다.
  @override
  Future<List<TeamSeasonStats>> getTeamSeasonStats() async => const [];
}

/// NBA 경기. 수집기가 올려둔 일정·결과를 읽는다.
class NbaGameRepository implements GameRepository {
  final NbaSource _source;

  NbaGameRepository(this._source);

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

  /// 경기별 박스스코어는 수집하지 않는다(경기 수 × 선수 수만큼 요청이 는다).
  @override
  Future<List<PlayerGameStats>> getBoxScore(Game game) async => const [];
}

/// NBA 선수.
///
/// 명단·사진·신상은 수집기가 올려둔 JSON에서, 시즌 스탯은 ESPN을 앱이
/// 직접 부른다(그쪽 엔드포인트는 CORS가 열려 있어 557명치를 미리 받아둘
/// 이유가 없다).
class NbaPlayerRepository implements PlayerRepository {
  static const _statsBase =
      'https://site.web.api.espn.com/apis/common/v3/sports/basketball/nba/athletes';

  final NbaSource _source;
  final http.Client _client;

  NbaPlayerRepository(this._source, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<List<Player>> getPlayers() => _source.players();

  @override
  Future<Player?> getPlayerById(String id) async {
    final players = await _source.players();
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  @override
  Future<List<Player>> getPlayersByTeam(String teamId) async {
    final players = await _source.players();
    return players.where((p) => p.teamId == teamId).toList();
  }

  /// ESPN은 팔로워 수를 주지 않는다. 지어낸 인기순 대신 이름순으로 준다.
  @override
  Future<List<Player>> getPlayersSortedByFollowers() async {
    final players = [...await _source.players()];
    players.sort((a, b) => a.name.compareTo(b.name));
    return players;
  }

  @override
  Future<List<Player>> searchPlayersByName(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return getPlayers();
    final players = await _source.players();
    return players
        .where((p) => p.name.toLowerCase().contains(trimmed))
        .toList();
  }

  @override
  Future<PlayerBio> getPlayerBio(Player player) async {
    final extras = await _source.playerExtras();
    final extra = extras[player.id];
    return PlayerBio(
      heightCm: _heightToCm(extra?.height) ?? 0,
      weightKg: _weightToKg(extra?.weight) ?? 0,
      birthDate:
          DateTime.tryParse(extra?.birthDate ?? '')?.toLocal() ??
          DateTime(1970),
      country: 'USA',
      college: extra?.college ?? '',
      // ESPN 로스터에는 드래프트 정보가 없다. 0은 화면에서 '-'로 표시된다.
      draftYear: 0,
      draftRound: 0,
      draftPick: 0,
    );
  }

  @override
  Future<List<PlayerSeasonStats>> getSeasonStatsHistory(Player player) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$_statsBase/${player.id}/stats'))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const NbaUnavailableException('선수 기록을 불러오지 못했어요.');
    }
    if (response.statusCode != 200) {
      throw const NbaUnavailableException('선수 기록을 불러오지 못했어요.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const NbaUnavailableException('선수 기록 형식을 읽지 못했어요.');
    }
    if (decoded is! Map) return const [];

    final categories = decoded['categories'];
    if (categories is! List) return const [];
    final averages = categories.whereType<Map>().where(
      (c) => c['name'] == 'averages',
    );
    if (averages.isEmpty) return const [];

    final category = averages.first;
    final names = (category['names'] as List?)?.cast<String>() ?? const [];
    final seasons = (category['statistics'] as List?) ?? const [];

    final result = <PlayerSeasonStats>[];
    for (final season in seasons.whereType<Map>()) {
      final stats = (season['stats'] as List?)?.cast<String>() ?? const [];
      double at(String key) => _statAt(names, stats, key);
      // "7.9-18.9"처럼 성공-시도가 한 칸에 들어온다.
      final (fgm, fga) = _pair(
        names,
        stats,
        'avgFieldGoalsMade-avgFieldGoalsAttempted',
      );
      final (tpm, tpa) = _pair(
        names,
        stats,
        'avgThreePointFieldGoalsMade-avgThreePointFieldGoalsAttempted',
      );
      final (ftm, fta) = _pair(
        names,
        stats,
        'avgFreeThrowsMade-avgFreeThrowsAttempted',
      );

      result.add(
        PlayerSeasonStats(
          playerId: player.id,
          season: season['season']?['displayName'] as String? ?? '',
          teamId: player.teamId,
          gamesPlayed: at('gamesPlayed').round(),
          minutes: at('avgMinutes'),
          points: at('avgPoints'),
          fgm: fgm,
          fga: fga,
          tpm: tpm,
          tpa: tpa,
          ftm: ftm,
          fta: fta,
          oreb: at('avgOffensiveRebounds'),
          dreb: at('avgDefensiveRebounds'),
          ast: at('avgAssists'),
          tov: at('avgTurnovers'),
          stl: at('avgSteals'),
          blk: at('avgBlocks'),
          pf: at('avgFouls'),
          // ESPN 평균 카테고리에는 +/-가 없다. 0으로 두고 화면에서 '-' 처리.
          plusMinus: 0,
        ),
      );
    }
    return result;
  }

  /// 557명치를 한 명씩 부르면 요청이 감당이 안 된다.
  /// 스탯 리더 화면은 NBA에서 빈 상태를 보여준다.
  @override
  Future<List<PlayerSeasonStats>> getCurrentSeasonStatsForAllPlayers() async =>
      const [];

  static double _statAt(List<String> names, List<String> stats, String key) {
    final index = names.indexOf(key);
    if (index < 0 || index >= stats.length) return 0;
    return double.tryParse(stats[index]) ?? 0;
  }

  static (double, double) _pair(
    List<String> names,
    List<String> stats,
    String key,
  ) {
    final index = names.indexOf(key);
    if (index < 0 || index >= stats.length) return (0, 0);
    final parts = stats[index].split('-');
    if (parts.length != 2) return (0, 0);
    return (double.tryParse(parts[0]) ?? 0, double.tryParse(parts[1]) ?? 0);
  }

  /// "6' 5\"" → cm.
  static int? _heightToCm(String? value) {
    if (value == null) return null;
    final match = RegExp(r"(\d+)'\s*(\d+)").firstMatch(value);
    if (match == null) return null;
    final feet = int.parse(match.group(1)!);
    final inches = int.parse(match.group(2)!);
    return ((feet * 12 + inches) * 2.54).round();
  }

  /// "205 lbs" → kg.
  static int? _weightToKg(String? value) {
    if (value == null) return null;
    final match = RegExp(r'(\d+)').firstMatch(value);
    if (match == null) return null;
    return (int.parse(match.group(1)!) * 0.453592).round();
  }
}
