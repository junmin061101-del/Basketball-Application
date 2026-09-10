import 'dart:convert';

import 'package:basket_it/data/models/player.dart';
import 'package:basket_it/data/repositories/nba_repositories.dart';
import 'package:basket_it/data/repositories/nba_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// ESPN이 실제로 주는 모양(라벨 배열 + 값 배열, 성공-시도는 한 칸에 묶임).
const espnStats = {
  'categories': [
    {
      'name': 'averages',
      'names': [
        'gamesPlayed',
        'gamesStarted',
        'avgMinutes',
        'avgFieldGoalsMade-avgFieldGoalsAttempted',
        'fieldGoalPct',
        'avgThreePointFieldGoalsMade-avgThreePointFieldGoalsAttempted',
        'threePointFieldGoalPct',
        'avgFreeThrowsMade-avgFreeThrowsAttempted',
        'freeThrowPct',
        'avgOffensiveRebounds',
        'avgDefensiveRebounds',
        'avgRebounds',
        'avgAssists',
        'avgBlocks',
        'avgSteals',
        'avgFouls',
        'avgTurnovers',
        'avgPoints',
      ],
      'statistics': [
        {
          'season': {'displayName': '2025-26'},
          'stats': [
            '79', '79', '39.5',
            '7.9-18.9', '41.7',
            '0.8-2.7', '29.0',
            '4.4-5.8', '75.4',
            '1.3', '4.2', '5.5',
            '5.9', '0.7', '1.6', '1.9', '3.5', '20.9',
          ],
        },
      ],
    },
    {'name': 'totals', 'names': <String>[], 'statistics': <Object>[]},
  ],
};

final player = Player(
  id: '1966',
  name: 'LeBron James',
  teamId: '13',
  position: PlayerPosition.sf,
  backNumber: 6,
  followerCount: 0,
);

NbaPlayerRepository repoReturning(http.Response Function() handler) =>
    NbaPlayerRepository(
      NbaSource(baseUrl: 'https://example.test/nba'),
      client: MockClient((_) async => handler()),
    );

void main() {
  test('ESPN 평균 스탯을 시즌 기록으로 바꾼다', () async {
    final repository = repoReturning(
      () => http.Response.bytes(utf8.encode(jsonEncode(espnStats)), 200),
    );

    final seasons = await repository.getSeasonStatsHistory(player);
    expect(seasons, hasLength(1));

    final s = seasons.single;
    expect(s.season, '2025-26');
    expect(s.gamesPlayed, 79);
    expect(s.minutes, 39.5);
    expect(s.points, 20.9);
    // "7.9-18.9" 같은 성공-시도 묶음을 갈라 담는다.
    expect(s.fgm, 7.9);
    expect(s.fga, 18.9);
    expect(s.tpm, 0.8);
    expect(s.tpa, 2.7);
    expect(s.ftm, 4.4);
    expect(s.fta, 5.8);
    expect(s.oreb, 1.3);
    expect(s.dreb, 4.2);
    expect(s.ast, 5.9);
    expect(s.blk, 0.7);
    expect(s.stl, 1.6);
    expect(s.pf, 1.9);
    expect(s.tov, 3.5);
  });

  test('성공률은 ESPN 발표치와 1%p 안쪽으로 맞는다', () async {
    // ESPN은 경기당 성공·시도를 소수 첫째자리로 반올림해 준다(0.8-2.7).
    // 그 값으로 성공률을 되계산하면 원래 비율과 조금 어긋난다.
    // 예: 0.8/2.7 = 29.6%인데 ESPN 발표는 29.0%.
    // 시도가 적은 부문일수록 오차가 커지므로 1%p까지는 정상으로 본다.
    final repository = repoReturning(
      () => http.Response.bytes(utf8.encode(jsonEncode(espnStats)), 200),
    );
    final s = (await repository.getSeasonStatsHistory(player)).single;
    expect(s.fgPct * 100, closeTo(41.7, 1.0));
    expect(s.tpPct * 100, closeTo(29.0, 1.0));
    expect(s.ftPct * 100, closeTo(75.4, 1.0));
    expect(s.reb, closeTo(5.5, 0.01));
  });

  test('averages 카테고리가 없으면 빈 목록', () async {
    final repository = repoReturning(
      () => http.Response.bytes(
        utf8.encode(jsonEncode({'categories': <Object>[]})),
        200,
      ),
    );
    expect(await repository.getSeasonStatsHistory(player), isEmpty);
  });

  test('요청이 실패하면 안내 메시지를 담은 예외', () async {
    final repository = repoReturning(() => http.Response('nope', 500));
    await expectLater(
      repository.getSeasonStatsHistory(player),
      throwsA(isA<NbaUnavailableException>()),
    );
  });
}
