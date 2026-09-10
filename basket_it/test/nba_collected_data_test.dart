import 'dart:convert';

import 'package:basket_it/data/models/award_race.dart';
import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/data/models/player.dart';
import 'package:basket_it/data/models/player_bio.dart';
import 'package:basket_it/data/models/player_season_stats.dart';
import 'package:basket_it/data/repositories/nba_repositories.dart';
import 'package:basket_it/data/repositories/collected_repositories.dart';
import 'package:basket_it/data/repositories/league_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const base = 'https://example.test/nba';

/// 수집기가 만드는 파일 모양 그대로.
final files = <String, Object>{
  'players': {
    'players': [
      {
        // 수집기가 이름을 한국어로 바꾸고 영문은 nameEn에 남긴다
        'id': 'p1', 'name': '르브론 제임스', 'nameEn': 'LeBron James',
        'teamId': '13', 'position': 'sf',
        'positionLabel': '포워드', 'backNumber': 23,
        'headshot': 'https://a.espncdn.com/i/headshots/nba/players/full/1966.png',
        'height': "6' 9\"", 'weight': '250 lbs', 'college': null,
        'birthDate': '1984-12-30T08:00Z',
        'draftYear': 2003, 'draftRound': 1, 'draftPick': 1,
        // 국적 정보는 없고 출생국만 있다
        'citizenship': null, 'birthCountry': 'USA',
      },
      {
        'id': 'p5',
        'name': 'Karl-Anthony Towns',
        'teamId': '18',
        'position': 'c',
        'backNumber': 32,
        'draftYear': 2015, 'draftRound': 1, 'draftPick': 1,
        // 미국 출생이지만 국적은 도미니카
        'citizenship': 'Dominican Republic', 'birthCountry': 'USA',
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
      {
        'playerId': 'p1',
        'teamId': '13',
        'gamesPlayed': 80,
        'points': 25.1,
        'reb': 7.3,
        'ast': 8.0,
        'stl': 1.2,
        'blk': 0.6,
        // 선수별로 따로 받아 온 값
        'oreb': 1.1,
        'dreb': 6.2,
        'dd2': 30,
        'td3': 8,
        'gameHigh': 45,
      },
      {
        'playerId': 'p2',
        'teamId': '13',
        'gamesPlayed': 56,
        'points': 12.0,
        'reb': 3.0,
      },
      // 두 경기만 뛰고 평균 40점 → 기준 미달이라 순위에서 빠져야 한다
      {
        'playerId': 'p4',
        'teamId': '13',
        'gamesPlayed': 2,
        'points': 40.0,
        'reb': 1.0,
      },
    ],
  },
  'teams': {
    'teams': [
      {
        'id': '13', 'city': 'LA', 'name': '레이커스', 'shortName': 'LA 레이커스',
        'abbreviation': 'LAL', 'color': '#552583',
        'logo': 'https://a.espncdn.com/i/teamlogos/nba/500/lal.png',
      },
    ],
  },
  'ladders': {
    'currentSeason': '2025-26',
    'awards': [
      {
        'award': 'mvp',
        'ladder': {
          'title': 'Kia MVP Ladder: final pick',
          'url': 'https://www.nba.com/news/kia-mvp-ladder-april-17-2026-edition',
          'publishedAt': '2026-04-17T11:01:29Z',
          'season': '2025-26',
          'author': 'Shaun Powell',
          'entries': [
            {
              'rank': 2, 'name': '니콜라 요키치', 'nameEn': 'Nikola Jokić',
              'playerId': '3112335', 'teamId': '7',
              'previousRank': 3, 'movement': 'up',
            },
            {
              'rank': 1, 'name': '셰이 길저스-알렉산더',
              'nameEn': 'Shai Gilgeous-Alexander', 'playerId': '4278073',
              'teamId': '25', 'previousRank': 2, 'movement': 'up',
            },
            {
              // 선수 목록에서 못 찾은 선수: 영문 이름 그대로, id 없음
              'rank': 6, 'name': 'Someone Retired', 'nameEn': 'Someone Retired',
              'playerId': null, 'teamId': '12', 'previousRank': null,
              'movement': 'new',
            },
          ],
        },
        'result': {
          'season': '2025-26',
          'url': 'https://www.nba.com/news/2025-2026-regular-season-awards',
          'winner': {
            'name': '셰이 길저스-알렉산더', 'nameEn': 'Shai Gilgeous-Alexander',
            'playerId': '4278073', 'teamId': '25',
          },
          'finalists': [
            {
              'name': '셰이 길저스-알렉산더', 'nameEn': 'Shai Gilgeous-Alexander',
              'playerId': '4278073', 'teamId': '25', 'isWinner': true,
            },
            {
              'name': '니콜라 요키치', 'nameEn': 'Nikola Jokić',
              'playerId': '3112335', 'teamId': '7', 'isWinner': false,
            },
          ],
        },
      },
      {
        // NBA.com이 DPOY 사다리를 싣지 않는다 → 결과만
        'award': 'dpoy',
        'ladder': null,
        'result': {
          'season': '2025-26',
          'url': 'https://www.nba.com/news/2025-2026-regular-season-awards',
          'winner': {
            'name': '빅터 웸반야마', 'nameEn': 'Victor Wembanyama',
            'playerId': '5104157', 'teamId': '24',
          },
          'finalists': [],
        },
      },
    ],
  },
  'team_stats': {
    'team_stats': [
      {
        'teamId': '13',
        'pointsFor': 116.3,
        'pointsAgainst': 112.4,
        'rebounds': 41.0,
        'fgm': 42.0,
        'fga': 83.7,
        'oreb': 9.4,
        'dreb': 31.5,
      },
    ],
  },
  'boxscores/g1': {
    'gameId': 'g1',
    'lines': [
      {
        'playerId': 'p1',
        'teamId': '13',
        'minutes': 25,
        'points': 8,
        'fgm': 3,
        'fga': 5,
        'tpm': 1,
        'tpa': 1,
        'ftm': 1,
        'fta': 3,
        'oreb': 1,
        'dreb': 5,
        'ast': 0,
        'tov': 1,
        'stl': 0,
        'blk': 0,
        'pf': 2,
        'plusMinus': 2,
      },
    ],
  },
};

LeagueDataSource source() => LeagueDataSource(
  leagueLabel: 'NBA',
  baseUrl: base,
  client: MockClient((request) async {
    final path = request.url.path
        .replaceFirst('/nba/', '')
        .replaceFirst('.json', '');
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
  id: 'p1',
  name: 'LeBron James',
  teamId: '13',
  position: PlayerPosition.sf,
  backNumber: 23,
);

void main() {
  group('스탯 리더', () {
    test('리더 목록은 출전 수로 거르지 않는다 (자격은 랭킹 부문마다 따진다)', () async {
      // 70% 출전 기준은 경기당 기록에만 해당한다. 더블더블·최다 득점 같은
      // 누적 기록은 적게 뛴 선수도 들어가야 해서 저장소에서는 거르지 않는다.
      final repo = NbaPlayerRepository(source());
      final stats = await repo.getCurrentSeasonStatsForAllPlayers();
      expect(stats.map((s) => s.playerId), unorderedEquals(['p1', 'p2', 'p4']));
    });

    test('공격/수비 리바운드와 누적 기록을 읽는다', () async {
      final stats = await source().leaders();
      final p1 = stats.firstWhere((s) => s.playerId == 'p1');
      expect(p1.hasReboundSplit, isTrue);
      expect([p1.oreb, p1.dreb], [1.1, 6.2]);
      expect([p1.doubleDoubles, p1.tripleDoubles, p1.gameHigh], [30, 8, 45]);

      // 선수별 기록을 아직 못 받은 선수: 총합은 맞고, 나뉜 값은 없다고 표시
      final p2 = stats.firstWhere((s) => s.playerId == 'p2');
      expect(p2.hasReboundSplit, isFalse);
      expect(p2.reb, 3.0);
      expect(p2.doubleDoubles, isNull);
    });

    test('리바운드 총합이 그대로 유지된다', () async {
      final stats = await source().leaders();
      final p1 = stats.firstWhere((s) => s.playerId == 'p1');
      expect(p1.reb, closeTo(7.3, 0.001));
      expect(p1.season, '2025-26');
    });
  });

  test('팀 시즌 평균을 읽는다 (실점 포함)', () async {
    final stats = await CollectedTeamRepository(source()).getTeamSeasonStats();
    final lal = stats.single;
    expect(lal.pointsFor, 116.3);
    expect(lal.pointsAgainst, 112.4);
    expect(lal.fgPct, closeTo(42.0 / 83.7, 0.0001));
  });

  group('박스스코어', () {
    test('끝난 경기는 수집된 기록을 준다', () async {
      final lines = await CollectedGameRepository(source())
          .getBoxScore(game('g1', GameStatus.finished));
      final line = lines.single;
      expect(line.points, 8);
      expect(
        [line.fgm, line.fga, line.tpm, line.tpa, line.ftm, line.fta],
        [3, 5, 1, 1, 1, 3],
      );
      expect(line.reb, 6);
      expect(line.plusMinus, 2);
    });

    test('예정 경기는 요청하지 않고 빈 목록', () async {
      expect(
        await CollectedGameRepository(source())
            .getBoxScore(game('g1', GameStatus.scheduled)),
        isEmpty,
      );
    });

    test('아직 파일이 없는 경기는 오류 대신 빈 목록', () async {
      expect(
        await CollectedGameRepository(source())
            .getBoxScore(game('nope', GameStatus.finished)),
        isEmpty,
      );
    });
  });

  group('드래프트', () {
    Future<PlayerBio> bioOf(String id) => NbaPlayerRepository(source())
        .getPlayerBio(
          Player(
            id: id,
            name: '',
            teamId: '13',
            position: PlayerPosition.sf,
            backNumber: 0,
          ),
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
            {
              'season': {'displayName': '2003-04'},
              'stats': ['79', '20.9'],
            },
            {
              'season': {'displayName': '2024-25'},
              'stats': ['70', '24.4'],
            },
            {
              'season': {'displayName': '2025-26'},
              'stats': ['60', '25.1'],
            },
          ],
        },
      ],
    };
    final repo = NbaPlayerRepository(
      source(),
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode(jsonEncode(body)), 200),
      ),
    );
    final seasons = await repo.getSeasonStatsHistory(lebron);
    expect(seasons.map((s) => s.season), ['2025-26', '2024-25', '2003-04']);
    expect(seasons.first.points, 25.1);
  });

  test('KBL 목업 드래프트 표기는 그대로다', () {
    final bio = PlayerBio(
      heightCm: 190,
      weightKg: 85,
      birthDate: DateTime(2000),
      country: 'KOR',
      college: '',
      draftYear: 2020,
      draftRound: 1,
      draftPick: 3,
    );
    expect(bio.draftLabel, '2020년 1라운드 3순위');
  });

  group('국적', () {
    Future<PlayerBio> bioOf(String id) => NbaPlayerRepository(source())
        .getPlayerBio(
          Player(
            id: id,
            name: '',
            teamId: '13',
            position: PlayerPosition.sf,
            backNumber: 0,
          ),
        );

    test('국적이 있으면 출생국보다 국적을 쓴다', () async {
      final bio = await bioOf('p5');
      expect(bio.countryLabel, 'Dominican Republic');
      expect(bio.countryTitle, '국적');
    });

    test('국적이 없으면 출생국을 쓰고 칸 이름도 출생국으로 바꾼다', () async {
      // 출생국을 "국적"이라고 적으면 카이리 어빙(호주 출생·미국 국적) 같은
      // 선수가 틀리게 나온다.
      final bio = await bioOf('p1');
      expect(bio.countryLabel, 'USA');
      expect(bio.countryTitle, '출생국');
    });

    test('둘 다 없으면 USA로 채우지 않고 -', () async {
      final bio = await bioOf('p3');
      expect(bio.countryLabel, '-');
      expect(bio.countryTitle, '국적');
    });

    test('출신 대학이 없으면 빈칸 대신 -', () async {
      expect((await bioOf('p1')).collegeLabel, '-');
    });
  });

  group('시즌별 기록의 팀', () {
    Future<List<PlayerSeasonStats>> historyFrom(
      List<Map<String, Object?>> rows,
    ) {
      final body = {
        'categories': [
          {
            'name': 'averages',
            'names': ['gamesPlayed', 'avgPoints'],
            'statistics': rows,
          },
        ],
      };
      return NbaPlayerRepository(
        source(),
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(jsonEncode(body)), 200),
        ),
      ).getSeasonStatsHistory(lebron);
    }

    test('시즌마다 그때 뛴 팀을 쓴다 (현재 소속팀이 아니라)', () async {
      final seasons = await historyFrom([
        {
          'teamId': '5',
          'season': {'displayName': '2003-04'},
          'stats': ['79', '20.9'],
        },
        {
          'teamId': '14',
          'season': {'displayName': '2010-11'},
          'stats': ['79', '26.7'],
        },
        {
          'teamId': '13',
          'season': {'displayName': '2025-26'},
          'stats': ['60', '20.9'],
        },
      ]);
      expect(seasons.map((s) => s.teamId), ['13', '14', '5']);
    });

    test('트레이드된 시즌은 합계 줄을 맨 앞에, 팀별 줄은 많이 뛴 순', () async {
      final seasons = await historyFrom([
        {
          'teamId': '6',
          'season': {'displayName': '2023-24'},
          'stats': ['70', '33.9'],
        },
        {
          'teamId': '6',
          'season': {'displayName': '2024-25'},
          'stats': ['22', '28.1'],
        },
        {
          'teamId': '13',
          'season': {'displayName': '2024-25'},
          'stats': ['28', '28.2'],
        },
        {
          'season': {'displayName': '2024-25'},
          'stats': ['50', '28.2'],
        },
      ]);
      expect(
        seasons.map(
          (s) =>
              '${s.season}/${s.isTotals ? 'TOT' : s.teamId}/${s.gamesPlayed}',
        ),
        ['2024-25/TOT/50', '2024-25/13/28', '2024-25/6/22', '2023-24/6/70'],
      );
      // "이 시즌 평균"은 맨 앞 줄을 쓰므로 한 팀 부분 기록이 아니라 시즌 전체가 나온다.
      expect(seasons.first.gamesPlayed, 50);
    });

    test('줄이 하나뿐인 시즌에 팀이 빠졌으면 합계가 아니라 현재 팀으로 채운다', () async {
      final seasons = await historyFrom([
        {
          'season': {'displayName': '2025-26'},
          'stats': ['60', '25.1'],
        },
      ]);
      expect(seasons.single.isTotals, isFalse);
      expect(seasons.single.teamId, lebron.teamId);
    });
  });

  group('한국어 표기', () {
    test('선수는 한국어 이름과 영문 이름·사진을 함께 갖는다', () async {
      final p1 = (await source().players()).firstWhere((p) => p.id == 'p1');
      expect(p1.name, '르브론 제임스');
      expect(p1.englishName, 'LeBron James');
      expect(p1.photoUrl, endsWith('1966.png'));
    });

    test('한글로도, 영문(대소문자 무관)으로도 검색된다', () async {
      final repo = NbaPlayerRepository(source());
      expect((await repo.searchPlayersByName('르브론')).map((p) => p.id), ['p1']);
      expect((await repo.searchPlayersByName('lebron')).map((p) => p.id), ['p1']);
      expect(await repo.searchPlayersByName('커리'), isEmpty);
    });

    test('팀은 한국어 이름과 ESPN 로고를 갖는다', () async {
      final team = (await source().teams()).single;
      expect(team.fullName, 'LA 레이커스');
      expect(team.shortName, 'LA 레이커스');
      expect(team.logoUrl, endsWith('lal.png'));
    });
  });

  group('수상 레이스', () {
    test('사다리는 순위순으로 정렬하고 변화·선수 id를 읽는다', () async {
      final races = await source().awardRaces();
      final ladder = races.raceOf(AwardType.mvp).ladder!;
      expect(ladder.entries.map((e) => e.rank), [1, 2, 6]);
      expect(ladder.entries.first.name, '셰이 길저스-알렉산더');
      expect(ladder.entries.first.movement, RankMovement.up);
      expect(ladder.entries.last.playerId, isNull);
      expect(ladder.entries.last.movement, RankMovement.newEntry);
      expect(ladder.author, 'Shaun Powell');
      expect(ladder.season, '2025-26');
    });

    test('수상 결과: 수상자와 후보(수상자 표시 포함)', () async {
      final result = (await source().awardRaces()).raceOf(AwardType.mvp).result!;
      expect(result.winner!.playerId, '4278073');
      expect(result.finalists.where((f) => f.isWinner).single.playerId, '4278073');
    });

    test('사다리가 없는 상도 수상 결과는 보여준다', () async {
      final race = (await source().awardRaces()).raceOf(AwardType.dpoy);
      expect(race.ladder, isNull);
      expect(race.result!.winner!.name, '빅터 웸반야마');
    });

    test('수집 결과에 없는 상은 빈 레이스로 준다', () async {
      final race = (await source().awardRaces()).raceOf(AwardType.roy);
      expect(race.ladder, isNull);
      expect(race.result, isNull);
    });
  });
}
