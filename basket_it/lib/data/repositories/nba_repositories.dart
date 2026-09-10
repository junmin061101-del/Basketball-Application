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

  /// 수집기가 팀마다 받아둔 시즌 평균. 실점은 순위 데이터에서 온다.
  @override
  Future<List<TeamSeasonStats>> getTeamSeasonStats() => _source.teamStats();
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

  /// 수집기가 끝난·진행 중 경기마다 받아둔 박스스코어. 예정 경기는 빈 목록.
  @override
  Future<List<PlayerGameStats>> getBoxScore(Game game) async {
    if (game.status == GameStatus.scheduled) return const [];
    return _source.boxScore(game.id);
  }
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

  /// 팀 선수단. 리더 목록·박스스코어에서만 합쳐 둔 로스터 밖 선수는 뺀다.
  @override
  Future<List<Player>> getPlayersByTeam(String teamId) async {
    final players = await _source.players();
    final offRoster = await _source.offRosterIds();
    return players
        .where((p) => p.teamId == teamId && !offRoster.contains(p.id))
        .toList();
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
    if (query.trim().isEmpty) return getPlayers();
    final players = await _source.players();
    // 한국어 이름("웸반야마")과 영문 이름("wemby")을 모두 받는다.
    return players.where((p) => p.matchesQuery(query)).toList();
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
      // 국적이 있으면 국적을, 없으면 출생 국가를 쓰고 그 사실을 표시한다.
      // 둘 다 없으면 비워 '-'로 보인다. 'USA'로 채우면 요키치·돈치치까지
      // 미국으로 나온다.
      country: extra?.citizenship ?? extra?.birthCountry ?? '',
      countryIsBirthplace:
          extra?.citizenship == null && extra?.birthCountry != null,
      college: extra?.college ?? '',
      // 조회 전이면 -1(화면에 '-'), 조회했는데 기록이 없으면 0(미지명).
      draftYear: extra == null || !extra.draftKnown
          ? PlayerBio.draftUnknown
          : extra.draftYear ?? 0,
      draftRound: extra?.draftRound ?? 0,
      draftPick: extra?.draftPick ?? 0,
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

    // 시즌 중 트레이드된 선수는 한 시즌이 팀별 줄 + 합계 줄로 나뉘어 온다
    // (돈치치 2024-25: DAL 22경기 / LAL 28경기 / Totals 50경기). 합계 줄에는
    // teamId가 없다. 줄이 하나뿐인 시즌에서 teamId가 빠진 건 합계가 아니라
    // 그냥 누락이라 보고 현재 팀으로 채운다.
    final rowsPerSeason = <String, int>{};
    for (final season in seasons.whereType<Map>()) {
      final name = season['season']?['displayName'] as String? ?? '';
      rowsPerSeason[name] = (rowsPerSeason[name] ?? 0) + 1;
    }

    final result = <PlayerSeasonStats>[];
    for (final season in seasons.whereType<Map>()) {
      final seasonName = season['season']?['displayName'] as String? ?? '';
      final rawTeamId = season['teamId'];
      final isTotals =
          rawTeamId == null && (rowsPerSeason[seasonName] ?? 0) > 1;
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
          season: seasonName,
          // 시즌마다 그때 뛴 팀이 따로 온다. 현재 소속팀을 모든 시즌에 찍으면
          // 르브론의 클리블랜드·마이애미 시절이 전부 지금 팀으로 나온다.
          // 합계 줄은 빈 문자열로 두고 화면에서 합계로 표시한다.
          teamId: isTotals
              ? PlayerSeasonStats.totalsTeamId
              : '${rawTeamId ?? player.teamId}',
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
    // ESPN은 오래된 시즌부터 준다(르브론이면 2003-04가 맨 앞). 앱은 최근
    // 시즌이 0번이라고 가정하므로 뒤집는다. "2025-26"은 문자열 비교로도
    // 시간 순서와 같다.
    //
    // 같은 시즌 안에서는 합계 줄을 맨 앞에 둔다. "이 시즌 평균"이 맨 앞 줄을
    // 쓰므로, 트레이드된 선수도 한 팀 부분 기록이 아니라 시즌 전체가 나온다.
    // 나머지 팀별 줄은 많이 뛴 팀 먼저.
    result.sort((a, b) {
      final bySeason = b.season.compareTo(a.season);
      if (bySeason != 0) return bySeason;
      if (a.isTotals != b.isTotals) return a.isTotals ? -1 : 1;
      return b.gamesPlayed.compareTo(a.gamesPlayed);
    });
    return result;
  }

  /// 전 선수 이번 시즌 기록. 수집기가 한 번에 받아둔 것을 쓴다.
  ///
  /// 출전 수로 거르지 않고 전원을 준다. 순위 자격은 부문마다 다르다
  /// (경기당 기록은 출전 70%, 성공률은 누적 성공 개수, 더블더블은 제한 없음).
  /// 그 판단은 랭킹 화면의 부문 정의(ranking_categories.dart)가 한다.
  @override
  Future<List<PlayerSeasonStats>> getCurrentSeasonStatsForAllPlayers() {
    return _source.leaders();
  }

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
