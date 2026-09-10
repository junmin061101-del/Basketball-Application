import 'dart:convert';

import 'package:basket_it/data/models/player.dart';
import 'package:basket_it/data/repositories/kbl_repositories.dart';
import 'package:basket_it/data/repositories/league_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const base = 'https://example.test/kbl';

/// KBL 수집기(tools/fetch-kbl.js)가 만드는 파일 모양 그대로.
final files = <String, Object>{
  'players': {
    'players': [
      {
        'id': '290776', 'name': '허웅', 'nameEn': 'Heo Ung', 'teamId': 'kcc',
        'position': 'pg', 'positionLabel': '가드', 'backNumber': 3,
        'headshot': 'https://kbl.or.kr/files/kbl/players-photo/290776.png',
      },
      {
        // 아직 한 경기도 안 뛴 신인
        'id': '291999', 'name': '신인', 'teamId': 'sk', 'position': 'sf',
        'positionLabel': '포워드', 'backNumber': 0,
      },
      {
        // 기록에만 남은 은퇴 선수
        'id': '200001', 'name': '은퇴선수', 'teamId': 'sk', 'position': 'sf',
        'backNumber': 0, 'offRoster': true,
      },
    ],
  },
  'player_seasons': {
    'rows': [
      {
        'playerId': '290776', 'season': '2021-22', 'teamId': 'db',
        'teamName': '원주 DB', 'gamesPlayed': 54, 'points': 16.7,
        'oreb': 0.5, 'dreb': 2.0, 'reb': 2.5,
      },
      {
        'playerId': '290776', 'season': '2025-26', 'teamId': 'kcc',
        'teamName': '부산 KCC', 'gamesPlayed': 45, 'points': 16.4,
        'oreb': 0.4, 'dreb': 2.1, 'reb': 2.5,
      },
      {
        // 지금은 없는 구단: 팀 코드만 있고 앱 팀 목록에는 없다
        'playerId': '200001', 'season': '2021-22', 'teamId': '30',
        'teamName': '고양 오리온', 'gamesPlayed': 40, 'points': 8.0,
        'oreb': 1.0, 'dreb': 3.0, 'reb': 4.0,
      },
    ],
  },
  'leaders': {
    'season': '2025-26',
    'leaders': [
      {
        'playerId': '290776', 'teamId': 'kcc', 'gamesPlayed': 45,
        'points': 16.4, 'oreb': 0.4, 'dreb': 2.1, 'reb': 2.5,
        'dd2': 0, 'td3': 0, 'gameHigh': 51,
      },
    ],
  },
  'teams': {
    'teams': [
      {
        'id': 'kcc', 'city': '부산', 'name': 'KCC', 'shortName': 'KCC',
        'color': '#07215A',
        'logo': 'https://www.kbl.or.kr/assets/img/club/kcc/emblem-kcc01.png',
      },
    ],
  },
};

LeagueDataSource source() => LeagueDataSource(
  baseUrl: base,
  leagueLabel: 'KBL',
  client: MockClient((request) async {
    final path = request.url.path
        .replaceFirst('/kbl/', '')
        .replaceFirst('.json', '');
    final body = files[path];
    if (body == null) return http.Response('Not Found', 404);
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  }),
);

Player player(String id, {String teamId = 'kcc'}) => Player(
  id: id,
  name: '',
  teamId: teamId,
  position: PlayerPosition.pg,
  backNumber: 0,
);

void main() {
  test('선수 이름·영문 표기·사진·포지션을 읽는다', () async {
    final heo = (await source().players()).firstWhere((p) => p.id == '290776');
    expect(heo.name, '허웅');
    expect(heo.englishName, 'Heo Ung');
    expect(heo.positionText, '가드');
    expect(heo.photoUrl, endsWith('290776.png'));
    expect(heo.matchesQuery('heo'), isTrue);
  });

  test('팀은 공식 엠블럼 주소를 갖는다', () async {
    final kcc = (await source().teams()).single;
    expect(kcc.fullName, '부산 KCC');
    expect(kcc.logoUrl, contains('kbl.or.kr'));
  });

  group('시즌별 기록', () {
    test('최근 시즌이 맨 앞이고 시즌마다 그때 팀을 쓴다', () async {
      final seasons = await KblPlayerRepository(
        source(),
      ).getSeasonStatsHistory(player('290776'));
      expect(seasons.map((s) => s.season), ['2025-26', '2021-22']);
      expect(seasons.map((s) => s.teamId), ['kcc', 'db']);
      expect(seasons.first.hasReboundSplit, isTrue);
      expect(seasons.first.reb, closeTo(2.5, 0.001));
    });

    test('한 경기도 안 뛴 선수는 빈 목록 (지어낸 기록을 채우지 않는다)', () async {
      expect(
        await KblPlayerRepository(
          source(),
        ).getSeasonStatsHistory(player('291999', teamId: 'sk')),
        isEmpty,
      );
    });

    test('지금은 없는 구단 기록은 원본 팀 이름을 남긴다', () async {
      final seasons = await KblPlayerRepository(
        source(),
      ).getSeasonStatsHistory(player('200001', teamId: 'sk'));
      expect(seasons.single.teamId, '30');
      expect(seasons.single.teamName, '고양 오리온');
    });
  });

  test('신상은 KBL 원본에 없어 지어내지 않고 비워 둔다', () async {
    final bio = await KblPlayerRepository(
      source(),
    ).getPlayerBio(player('290776'));
    expect(bio.isEmpty, isTrue);
    expect(bio.heightLabel, '-');
    expect(bio.weightLabel, '-');
    expect(bio.birthWithAgeLabel(DateTime(2026, 9, 10)), '-');
    expect(bio.draftLabel, '-');
  });

  test('팀 선수단에는 기록에만 남은 은퇴 선수가 들어가지 않는다', () async {
    final repo = KblPlayerRepository(source());
    expect((await repo.getPlayersByTeam('sk')).map((p) => p.id), ['291999']);
    expect((await repo.getPlayers()).map((p) => p.id), contains('200001'));
  });

  test('랭킹용 이번 시즌 기록에 박스스코어로 센 최다 득점이 들어 있다', () async {
    final stats = await KblPlayerRepository(
      source(),
    ).getCurrentSeasonStatsForAllPlayers();
    expect(stats.single.gameHigh, 51);
    expect(stats.single.season, '2025-26');
  });

  test('파일이 아직 없으면 KBL 데이터가 준비되지 않았다고 알린다', () async {
    final empty = LeagueDataSource(
      baseUrl: base,
      leagueLabel: 'KBL',
      client: MockClient((_) async => http.Response('Not Found', 404)),
    );
    await expectLater(
      empty.teams(),
      throwsA(
        isA<LeagueDataUnavailableException>().having(
          (e) => e.message,
          'message',
          '아직 KBL 데이터가 준비되지 않았어요.',
        ),
      ),
    );
  });
}
