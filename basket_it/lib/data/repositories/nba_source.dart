import 'dart:convert';

import 'package:flutter/material.dart' show Color;
import 'package:http/http.dart' as http;

import '../models/game.dart';
import '../models/player.dart';
import '../models/team.dart';
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

  final Map<String, Future<List<dynamic>>> _cache = {};

  /// `<name>.json`을 읽어 그 안의 `<name>` 배열을 준다.
  Future<List<dynamic>> _load(String name) {
    return _cache.putIfAbsent(name, () async {
      final uri = Uri.parse('$baseUrl/$name.json');
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
        if (decoded is! Map) return const [];
        final list = decoded[name];
        return list is List ? list : const [];
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
      );
    }).toList();
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
        ),
    };
  }

  Team _toTeam(Map row) {
    final hex = (row['color'] as String? ?? '#1D428A').replaceAll('#', '');
    return Team(
      id: row['id'] as String? ?? '',
      city: row['city'] as String? ?? '',
      name: row['name'] as String? ?? '',
      shortName: row['shortName'] as String? ?? '',
      primaryColor: Color(int.parse('FF$hex', radix: 16)),
      // ESPN 로고는 원격 URL이라 asset이 아니다. 화면에서 별도로 그린다.
      logoAsset: null,
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

  const NbaPlayerExtra({
    this.headshot,
    this.height,
    this.weight,
    this.college,
    this.birthDate,
    this.positionLabel,
  });
}
