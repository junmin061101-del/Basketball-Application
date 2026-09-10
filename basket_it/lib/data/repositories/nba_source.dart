import 'dart:convert';

import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' as http;

import '../models/award_race.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/player_game_stats.dart';
import '../models/player_season_stats.dart';
import '../models/team.dart';
import '../models/team_season_stats.dart';
import '../models/team_standing.dart';

/// GitHub Actions가 ESPN에서 모아 GitHub Pages에 올려둔 NBA 데이터를 읽는다.
///
/// 팀·순위·일정·로스터를 주는 ESPN 엔드포인트에는 CORS 헤더가 없어 앱이
/// 직접 못 부른다. 그래서 수집기가 만들어 둔 정적 JSON을 쓴다.
/// 한 번 읽은 결과는 메모리에 들고 있어 화면을 오갈 때마다 다시 받지 않는다.
class NbaSource {
  static const defaultBaseUrl = String.fromEnvironment(
    'NBA_BASE_URL',
    defaultValue:
        'https://junmin061101-del.github.io/Basketball-Application/nba',
  );

  final String baseUrl;
  final http.Client _client;

  NbaSource({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? defaultBaseUrl,
      _client = client ?? http.Client();

  final Map<String, Future<Map<dynamic, dynamic>>> _cache = {};

  /// `<name>.json`을 읽어 그 안의 `<name>` 배열을 준다.
  Future<List<dynamic>> _load(String name) async {
    final doc = await _loadDoc(name);
    final list = doc[name];
    return list is List ? list : const [];
  }

  /// `<path>.json` 문서 전체를 읽는다. 결과는 캐시한다.
  Future<Map<dynamic, dynamic>> _loadDoc(String path) {
    return _cache.putIfAbsent(path, () async {
      final uri = Uri.parse('$baseUrl/$path.json');
      final http.Response response;
      try {
        response = await _client.get(uri).timeout(const Duration(seconds: 20));
      } catch (_) {
        throw const NbaUnavailableException('네트워크 연결을 확인해주세요.');
      }
      if (response.statusCode == 404) {
        throw const NbaUnavailableException('아직 NBA 데이터가 준비되지 않았어요.');
      }
      if (response.statusCode != 200) {
        throw const NbaUnavailableException('NBA 데이터를 불러오지 못했어요.');
      }
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return decoded is Map ? decoded : const {};
      } catch (_) {
        throw const NbaUnavailableException('NBA 데이터 형식을 읽지 못했어요.');
      }
    });
  }

  /// 다음에 다시 받아오도록 캐시를 버린다.
  void invalidate() => _cache.clear();

  Future<List<Team>> teams() async {
    final rows = await _load('teams');
    return rows.whereType<Map>().map(_toTeam).toList();
  }

  Future<List<TeamStanding>> standings() async {
    final rows = await _load('standings');
    return rows.whereType<Map>().map((r) {
      return TeamStanding(
        teamId: r['teamId'] as String? ?? '',
        wins: (r['wins'] as num?)?.toInt() ?? 0,
        losses: (r['losses'] as num?)?.toInt() ?? 0,
        gamesBehind: (r['gamesBehind'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  Future<List<Game>> games() async {
    final rows = await _load('games');
    final games = <Game>[];
    for (final row in rows.whereType<Map>()) {
      final startRaw = row['startTime'] as String?;
      final start = startRaw == null ? null : DateTime.tryParse(startRaw);
      if (start == null) continue;
      final local = start.toLocal();
      games.add(
        Game(
          id: row['id'] as String? ?? '',
          date: DateTime(local.year, local.month, local.day),
          homeTeamId: row['homeTeamId'] as String? ?? '',
          awayTeamId: row['awayTeamId'] as String? ?? '',
          homeScore: (row['homeScore'] as num?)?.toInt() ?? 0,
          awayScore: (row['awayScore'] as num?)?.toInt() ?? 0,
          status: switch (row['status']) {
            'live' => GameStatus.live,
            'finished' => GameStatus.finished,
            _ => GameStatus.scheduled,
          },
          startTime: local,
          liveClock: row['liveClock'] as String?,
        ),
      );
    }
    return games;
  }

  Future<List<Player>> players() async {
    final rows = await _load('players');
    return rows.whereType<Map>().map((r) {
      return Player(
        id: r['id'] as String? ?? '',
        name: r['name'] as String? ?? '',
        teamId: r['teamId'] as String? ?? '',
        position: switch (r['position']) {
          'pg' => PlayerPosition.pg,
          'sg' => PlayerPosition.sg,
          'pf' => PlayerPosition.pf,
          'c' => PlayerPosition.c,
          _ => PlayerPosition.sf,
        },
        backNumber: (r['backNumber'] as num?)?.toInt() ?? 0,
        // ESPN은 팔로워 수를 주지 않는다. 없는 값을 지어내지 않고 0으로 둔다.
        followerCount: 0,
        positionLabel: r['positionLabel'] as String?,
        // 수집기가 name을 한국어로 바꾸고 원래 영문은 nameEn에 남긴다.
        englishName: r['nameEn'] as String?,
        photoUrl: r['headshot'] as String?,
      );
    }).toList();
  }

  /// 지금 로스터에 없는 선수 id. 리더·박스스코어에만 나오는 선수들이다.
  Future<Set<String>> offRosterIds() async {
    final rows = await _load('players');
    return {
      for (final r in rows.whereType<Map>())
        if (r['offRoster'] == true) r['id'] as String? ?? '',
    };
  }

  /// 선수 사진·신장·대학처럼 Player에 담기지 않는 정보.
  Future<Map<String, NbaPlayerExtra>> playerExtras() async {
    final rows = await _load('players');
    return {
      for (final r in rows.whereType<Map>())
        (r['id'] as String? ?? ''): NbaPlayerExtra(
          headshot: r['headshot'] as String?,
          height: r['height'] as String?,
          weight: r['weight'] as String?,
          college: r['college'] as String?,
          birthDate: r['birthDate'] as String?,
          positionLabel: r['positionLabel'] as String?,
          // 키가 아예 없으면 아직 조회 전, null이면 미지명.
          draftKnown: r.containsKey('draftYear'),
          draftYear: (r['draftYear'] as num?)?.toInt(),
          draftRound: (r['draftRound'] as num?)?.toInt(),
          draftPick: (r['draftPick'] as num?)?.toInt(),
          citizenship: r['citizenship'] as String?,
          birthCountry: r['birthCountry'] as String?,
        ),
    };
  }

  /// 이번 시즌 전 선수 평균. 스탯 리더에 쓴다.
  Future<List<PlayerSeasonStats>> leaders() async {
    final doc = await _loadDoc('leaders');
    final season = doc['season'] as String? ?? '';
    final rows = doc['leaders'];
    if (rows is! List) return const [];
    double d(Map r, String k) => (r[k] as num?)?.toDouble() ?? 0;
    return rows.whereType<Map>().map((r) {
      final reb = d(r, 'reb');
      // 공격/수비 리바운드는 수집기가 선수별로 따로 받아 온다. 아직 못 받은
      // 선수는 총합만 있으므로 총합이 맞도록 수비 쪽에 담고 표시해 둔다.
      final hasSplit = r['oreb'] is num && r['dreb'] is num;
      return PlayerSeasonStats(
        playerId: r['playerId'] as String? ?? '',
        season: season,
        teamId: r['teamId'] as String? ?? '',
        gamesPlayed: (r['gamesPlayed'] as num?)?.toInt() ?? 0,
        minutes: d(r, 'minutes'),
        points: d(r, 'points'),
        fgm: d(r, 'fgm'),
        fga: d(r, 'fga'),
        tpm: d(r, 'tpm'),
        tpa: d(r, 'tpa'),
        ftm: d(r, 'ftm'),
        fta: d(r, 'fta'),
        oreb: hasSplit ? d(r, 'oreb') : 0,
        dreb: hasSplit ? d(r, 'dreb') : reb,
        hasReboundSplit: hasSplit,
        ast: d(r, 'ast'),
        tov: d(r, 'tov'),
        stl: d(r, 'stl'),
        blk: d(r, 'blk'),
        pf: d(r, 'pf'),
        plusMinus: 0,
        doubleDoubles: (r['dd2'] as num?)?.toInt(),
        tripleDoubles: (r['td3'] as num?)?.toInt(),
        gameHigh: (r['gameHigh'] as num?)?.toInt(),
      );
    }).toList();
  }

  /// MVP·올해의 수비수·신인왕 레이스(NBA.com 사다리와 시즌 수상 결과).
  Future<AwardRaces> awardRaces() async {
    return AwardRaces.parse(await _loadDoc('ladders'));
  }

  /// 팀별 시즌 평균.
  Future<List<TeamSeasonStats>> teamStats() async {
    final rows = await _load('team_stats');
    double d(Map r, String k) => (r[k] as num?)?.toDouble() ?? 0;
    return rows.whereType<Map>().map((r) {
      return TeamSeasonStats(
        teamId: r['teamId'] as String? ?? '',
        pointsFor: d(r, 'pointsFor'),
        pointsAgainst: d(r, 'pointsAgainst'),
        rebounds: d(r, 'rebounds'),
        assists: d(r, 'assists'),
        steals: d(r, 'steals'),
        blocks: d(r, 'blocks'),
        fgm: d(r, 'fgm'),
        fga: d(r, 'fga'),
        tpm: d(r, 'tpm'),
        tpa: d(r, 'tpa'),
        ftm: d(r, 'ftm'),
        fta: d(r, 'fta'),
        oreb: d(r, 'oreb'),
        dreb: d(r, 'dreb'),
        tov: d(r, 'tov'),
        pf: d(r, 'pf'),
      );
    }).toList();
  }

  /// 한 경기 박스스코어. 아직 기록이 없는 경기(예정)는 빈 목록.
  Future<List<PlayerGameStats>> boxScore(String gameId) async {
    final Map<dynamic, dynamic> doc;
    try {
      doc = await _loadDoc('boxscores/$gameId');
    } on NbaUnavailableException {
      // 끝나기 전이거나 아직 수집 전인 경기는 파일이 없다.
      _cache.remove('boxscores/$gameId');
      return const [];
    }
    final rows = doc['lines'];
    if (rows is! List) return const [];
    int i(Map r, String k) => (r[k] as num?)?.toInt() ?? 0;
    return rows.whereType<Map>().map((r) {
      return PlayerGameStats(
        playerId: r['playerId'] as String? ?? '',
        gameId: gameId,
        teamId: r['teamId'] as String? ?? '',
        minutes: i(r, 'minutes'),
        points: i(r, 'points'),
        fgm: i(r, 'fgm'),
        fga: i(r, 'fga'),
        tpm: i(r, 'tpm'),
        tpa: i(r, 'tpa'),
        ftm: i(r, 'ftm'),
        fta: i(r, 'fta'),
        oreb: i(r, 'oreb'),
        dreb: i(r, 'dreb'),
        ast: i(r, 'ast'),
        tov: i(r, 'tov'),
        stl: i(r, 'stl'),
        blk: i(r, 'blk'),
        pf: i(r, 'pf'),
        plusMinus: i(r, 'plusMinus'),
      );
    }).toList();
  }

  Team _toTeam(Map row) {
    final hex = (row['color'] as String? ?? '#1D428A').replaceAll('#', '');
    return Team(
      id: row['id'] as String? ?? '',
      city: row['city'] as String? ?? '',
      name: row['name'] as String? ?? '',
      shortName: row['shortName'] as String? ?? '',
      primaryColor: Color(int.parse('FF$hex', radix: 16)),
      // ESPN 로고는 원격 URL이라 asset이 아니다.
      logoAsset: null,
      logoUrl: row['logo'] as String?,
    );
  }
}

/// NBA 데이터를 못 가져왔을 때. 화면에 그대로 보여줄 한국어 메시지를 담는다.
class NbaUnavailableException implements Exception {
  final String message;
  const NbaUnavailableException(this.message);

  @override
  String toString() => message;
}

/// Player 모델에 자리가 없는 NBA 전용 정보.
class NbaPlayerExtra {
  final String? headshot;
  final String? height;
  final String? weight;
  final String? college;
  final String? birthDate;

  /// ESPN이 주는 포지션 표기(가드/포워드/센터). enum보다 이쪽이 정확하다.
  final String? positionLabel;

  /// 드래프트 정보를 조회했는지. false면 아직 모르는 것이고,
  /// true인데 [draftYear]가 null이면 미지명 선수다.
  final bool draftKnown;
  final int? draftYear;
  final int? draftRound;
  final int? draftPick;

  /// ESPN이 알려준 국적. 비어 있는 선수가 많다.
  final String? citizenship;

  /// 출생 국가. 국적과 다를 수 있다(카이리 어빙은 호주 출생).
  final String? birthCountry;

  const NbaPlayerExtra({
    this.headshot,
    this.height,
    this.weight,
    this.college,
    this.birthDate,
    this.positionLabel,
    this.draftKnown = false,
    this.draftYear,
    this.draftRound,
    this.draftPick,
    this.citizenship,
    this.birthCountry,
  });
}
