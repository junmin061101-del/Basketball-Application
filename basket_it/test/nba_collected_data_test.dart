import 'dart:convert';

import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/data/models/player.dart';
import 'package:basket_it/data/models/player_bio.dart';
import 'package:basket_it/data/repositories/nba_repositories.dart';
import 'package:basket_it/data/repositories/nba_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const base = 'https://example.test/nba';

/// 수집기가 만드는 파일 모양 그대로.
final files = <String, Object>{
  'players': {
    'players': [
      {
        'id': 'p1', 'name': 'LeBron James', 'teamId': '13', 'position': 'sf',
        'positionLabel': '포워드', 'backNumber': 23,
        'height': "6' 9\"", 'weight': '250 lbs', 'college': null,
        'birthDate': '1984-12-30T08:00Z',
        'draftYear': 2003, 'draftRound': 1, 'draftPick': 1,
      },
      {
        // 조회는 됐지만 드래프트 기록이 없다 → 미지명
        'id': 'p2', 'name': 'Undrafted Guy', 'teamId': '13', 'position': 'pg',
        'backNumber': 1,
        'draftYear': null, 'draftRound': null, 'draftPick': null,
      },
      {
        // 드래프트 키 자체가 없다 → 조회 실패, 아직 모름
        'id': 'p3', 'name': 'Lookup Failed', 'teamId': '13', 'position': 'c',
        'backNumber': 7,
      },
      {
        // 리더 목록에서만 합쳐진, 지금 로스터에 없는 선수
        'id': 'p4', 'name': 'Free Agent', 'teamId': '13', 'position': 'sf',
        'backNumber': 0, 'offRoster': true,
      },
    ],
  },
  'leaders': {
    'season': '2025-26',
    'leaders': [
      {'playerId': 'p1', 'teamId': '13', 'gamesPlayed': 80, 'points': 25.1, 'reb': 7.3, 'ast': 8.0, 'stl': 1.2, 'blk': 0.6},
      {'playerId': 'p2', 'teamId': '13', 'gamesPlayed': 56, 'points': 12.0, 'reb': 3.0},
      // 두 경기만 뛰고 평균 40점 → 기준 미달이라 순위에서 빠져야 한다
      {'playerId': 'p4', 'teamId': '13', 'gamesPlayed': 2, 'points': 40.0, 'reb': 1.0},
    ],
  },
  'team_stats': {
    'team_stats': [
      {'teamId': '13', 'pointsFor': 116.3, 'pointsAgainst': 112.4, 'rebounds': 41.0, 'fgm': 42.0, 'fga': 83.7, 'oreb': 9.4, 'dreb': 31.5},
    ],
  },
  'boxscores/g1': {
    'gameId': 'g1',
    'lines': [
      {'playerId': 'p1', 'teamId': '13', 'minutes': 25, 'points': 8, 'fgm': 3, 'fga': 5, 'tpm': 1, 'tpa': 1, 'ftm': 1, 'fta': 3, 'oreb': 1, 'dreb': 5, 'ast': 0, 'tov': 1, 'stl': 0, 'blk': 0, 'pf': 2, 'plusMinus': 2},
    ],
  },
};

NbaSource source() => NbaSource(
  baseUrl: base,
  client: MockClient((request) async {
    final path = request.url.path.replaceFirst('/nba/', '').replaceFirst('.json', '');
    final body = files[path];
    if (body == null) return http.Response('Not Found', 404);
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  }),
);

Game game(String id, GameStatus status) => Game(
  id: id,
  date: DateTime(2026, 4, 10),
  homeTeamId: '13',
  awayTeamId: '14',
  homeScore: 0,
  awayScore: 0,
  status: status,
  startTime: DateTime(2026, 4, 10, 19),
);

const lebron = Player(
  id: 'p1', name: 'LeBron James', teamId: '13',
  position: PlayerPosition.sf, backNumber: 23,
);

void main() {
  group('스탯 리더', () {
    test('가장 많이 뛴 선수의 70% 미만 출전자는 순위에서 뺀다', () async {
      final repo = NbaPlayerRepository(source());
      final stats = await repo.getCurrentSeasonStatsForAllPlayers();
      // 80경기의 70% = 56경기. p1(80), p2(56)는 남고 p4(2경기 40점)는 빠진다.
      expect(stats.map((s) => s.playerId), unorderedEquals(['p1', 'p2']));
    });

    test('리바운드 총합이 그대로 유지된다', () async {
      final stats = await source().leaders();
      final p1 = stats.firstWhere((s) => s.playerId == 'p1');
      expect(p1.reb, closeTo(7.3, 0.001));
      expect(p1.season, '2025-26');
    });
  });

  test('팀 시즌 평균을 읽는다 (실점 포함)', () async {
    final stats = await NbaTeamRepository(source()).getTeamSeasonStats();
    final lal = stats.single;
    expect(lal.pointsFor, 116.3);
    expect(lal.pointsAgainst, 112.4);
    expect(lal.fgPct, closeTo(42.0 / 83.7, 0.0001));
  });

  group('박스스코어', () {
    test('끝난 경기는 수집된 기록을 준다', () async {
      final lines = await NbaGameRepository(source()).getBoxScore(game('g1', GameStatus.finished));
      final line = lines.single;
      expect(line.points, 8);
      expect([line.fgm, line.fga, line.tpm, line.tpa, line.ftm, line.fta], [3, 5, 1, 1, 1, 3]);
      expect(line.reb, 6);
      expect(line.plusMinus, 2);
    });

    test('예정 경기는 요청하지 않고 빈 목록', () async {
      expect(await NbaGameRepository(source()).getBoxScore(game('g1', GameStatus.scheduled)), isEmpty);
    });

    test('아직 파일이 없는 경기는 오류 대신 빈 목록', () async {
      expect(await NbaGameRepository(source()).getBoxScore(game('nope', GameStatus.finished)), isEmpty);
    });
  });

  group('드래프트', () {
    Future<PlayerBio> bioOf(String id) => NbaPlayerRepository(source()).getPlayerBio(
      Player(id: id, name: '', teamId: '13', position: PlayerPosition.sf, backNumber: 0),
    );

    test('지명 선수', () async {
      expect((await bioOf('p1')).draftLabel, '2003년 1라운드 1순위');
    });

    test('조회했는데 기록이 없으면 미지명', () async {
      expect((await bioOf('p2')).draftLabel, '미지명');
    });

    test('조회에 실패한 선수를 미지명이라고 적지 않는다', () async {
      expect((await bioOf('p3')).draftLabel, '-');
    });
  });

  test('팀 선수단에는 로스터 밖 선수가 들어가지 않는다', () async {
    final roster = await NbaPlayerRepository(source()).getPlayersByTeam('13');
    expect(roster.map((p) => p.id), isNot(contains('p4')));
    expect(roster.map((p) => p.id), containsAll(['p1', 'p2', 'p3']));
  });

  test('선수 시즌 기록은 최근 시즌이 맨 앞에 온다', () async {
    // ESPN은 오래된 시즌부터 준다.
    const names = ['gamesPlayed', 'avgPoints'];
    final body = {
      'categories': [
        {
          'name': 'averages',
          'names': names,
          'statistics': [
            {'season': {'displayName': '2003-04'}, 'stats': ['79', '20.9']},
            {'season': {'displayName': '2024-25'}, 'stats': ['70', '24.4']},
            {'season': {'displayName': '2025-26'}, 'stats': ['60', '25.1']},
          ],
        },
      ],
    };
    final repo = NbaPlayerRepository(
      source(),
      client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(body)), 200)),
    );
    final seasons = await repo.getSeasonStatsHistory(lebron);
    expect(seasons.map((s) => s.season), ['2025-26', '2024-25', '2003-04']);
    expect(seasons.first.points, 25.1);
  });

  test('KBL 목업 드래프트 표기는 그대로다', () {
    final bio = PlayerBio(
      heightCm: 190, weightKg: 85, birthDate: DateTime(2000),
      country: 'KOR', college: '', draftYear: 2020, draftRound: 1, draftPick: 3,
    );
    expect(bio.draftLabel, '2020년 1라운드 3순위');
  });
}
