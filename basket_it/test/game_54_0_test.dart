import 'dart:math';

import 'package:basket_it/features/game540/game_54_0_rules.dart';
import 'package:basket_it/features/game540/models/game_54_0.dart';
import 'package:flutter_test/flutter_test.dart';

GamePlayer player({
  String id = 'p1',
  String name = '선수',
  PlayerLine line = PlayerLine.guard,
  String teamId = 'sk',
  double ppg = 10,
  double rpg = 3,
  double apg = 2,
  double spg = 0.5,
  double bpg = 0.2,
}) => GamePlayer(
  id: id,
  name: name,
  line: line,
  teamId: teamId,
  teamName: '서울 SK',
  season: '2025-2026',
  games: 50,
  mpg: 30,
  ppg: ppg,
  rpg: rpg,
  apg: apg,
  spg: spg,
  bpg: bpg,
);

/// 리그를 지배하는 급(자밀 워니 2024-25: 22.6점 11.9리바 4.4어시 수준 위).
GamePlayer star(String id, PlayerLine line, {String teamId = 'sk'}) => player(
  id: id,
  line: line,
  teamId: teamId,
  ppg: 25,
  rpg: 10,
  apg: 5,
  spg: 1.5,
  bpg: 1,
);

void main() {
  group('자리 적합도', () {
    test('가드는 가드 자리에서 100%, 센터 자리에서 크게 깎인다', () {
      expect(slotFit(PlayerLine.guard, LineupSlot.pg), 1.0);
      expect(slotFit(PlayerLine.guard, LineupSlot.sg), 1.0);
      expect(slotFit(PlayerLine.guard, LineupSlot.c), lessThan(0.3));
    });

    test('센터는 센터·파워포워드까지는 제 몫을 한다', () {
      expect(slotFit(PlayerLine.center, LineupSlot.c), 1.0);
      expect(slotFit(PlayerLine.center, LineupSlot.pf), greaterThan(0.8));
      expect(slotFit(PlayerLine.center, LineupSlot.pg), lessThan(0.3));
    });
  });

  group('승수 계산', () {
    Map<LineupSlot, GamePlayer> lineupOf(List<GamePlayer> players) => {
      for (final (i, p) in players.indexed) LineupSlot.values[i]: p,
    };

    List<GamePlayer> bestFive() => [
      star('1', PlayerLine.guard),
      star('2', PlayerLine.guard),
      star('3', PlayerLine.forward),
      star('4', PlayerLine.forward),
      star('5', PlayerLine.center),
    ];

    test('최고 선수들이 제자리에 서면 54승 0패', () {
      final result = simulate(lineupOf(bestFive()));
      expect(result.wins, kbl54Games);
      expect(result.isPerfect, isTrue);
      expect(result.fitScore, 100);
    });

    test('같은 재능이라도 엉뚱한 자리에 서면 승수가 깎인다', () {
      final right = simulate(lineupOf(bestFive()));
      // 센터 셋을 가드 자리에, 가드 둘을 골밑에 세운 라인업.
      final wrong = simulate(
        lineupOf([
          star('1', PlayerLine.center),
          star('2', PlayerLine.center),
          star('3', PlayerLine.center),
          star('4', PlayerLine.guard),
          star('5', PlayerLine.guard),
        ]),
      );
      expect(wrong.fitScore, lessThan(60));
      expect(wrong.wins, lessThan(right.wins));
      expect(right.wins - wrong.wins, greaterThan(5));
    });

    test('기록이 적은 선수만 모으면 승수가 낮다', () {
      final result = simulate(
        lineupOf([
          for (var i = 0; i < 5; i++)
            player(id: '$i', ppg: 4, rpg: 1, apg: 1, spg: 0.2, bpg: 0),
        ]),
      );
      expect(result.powerScore, lessThan(20));
      expect(result.wins, lessThan(10));
    });

    test('결과에 다섯 명의 경기당 기록 합계가 담긴다', () {
      final result = simulate(
        lineupOf([
          for (var i = 0; i < 5; i++)
            player(id: '$i', ppg: 10, rpg: 4, apg: 3, spg: 1, bpg: 0.5),
        ]),
      );
      expect(result.ppg, closeTo(50, 0.001));
      expect(result.rpg, closeTo(20, 0.001));
      expect(result.apg, closeTo(15, 0.001));
      expect(result.spg, closeTo(5, 0.001));
      expect(result.bpg, closeTo(2.5, 0.001));
    });

    test('다섯 자리가 다 차기 전에는 0승', () {
      expect(simulate({LineupSlot.pg: player()}).wins, 0);
    });
  });

  group('순위', () {
    test('더 많이 이길수록 앞 순위, 상위 %도 작아진다', () {
      const distribution = WinDistribution([10, 14, 20, 20, 31, 44]);
      expect(distribution.rankOf(50), 1);
      expect(distribution.rankOf(20), 3);
      expect(distribution.rankOf(0), 7);
    });

    test('견줄 라인업을 만들어 분포를 낸다', () {
      final draw = RoundDraw(
        byCondition: {
          for (var team = 0; team < 6; team++)
            RoundCondition(teamId: 'team$team', teamName: '팀$team'): [
              for (var i = 0; i < 6; i++)
                player(id: 'p$team$i', ppg: 5.0 + i * 4),
            ],
        },
        random: Random(7),
      );
      final distribution = WinDistribution.sample(draw, size: 50);
      expect(distribution.size, 50);
      for (var i = 1; i < distribution.wins.length; i++) {
        expect(
          distribution.wins[i],
          greaterThanOrEqualTo(distribution.wins[i - 1]),
        );
      }
    });

    test('순위를 매기면 상위 %가 함께 나온다', () {
      const base = LineupResult(wins: 30, powerScore: 0, fitScore: 0);
      expect(base.topPercent, isNull);
      final ranked = base.withRank(rank: 25, rankPool: 1000);
      expect(ranked.wins, 30);
      expect(ranked.topPercent, closeTo(2.5, 0.001));
    });
  });

  group('라운드 뽑기', () {
    final pool = {
      const RoundCondition(teamId: 'sk', teamName: '서울 SK'): [
        player(id: 'a'),
        player(id: 'b'),
      ],
      const RoundCondition(teamId: 'db', teamName: '원주 DB'): [player(id: 'c')],
    };

    test('선수가 있는 구단에서만 뽑는다', () {
      final draw = RoundDraw(byCondition: pool, random: Random(1));
      for (var i = 0; i < 20; i++) {
        final drawn = draw.draw();
        expect(pool.keys, contains(drawn!.condition));
        expect(
          pool[drawn.condition]!.map((p) => p.id),
          contains(drawn.player.id),
        );
      }
    });

    test('구단을 뽑으면 거기서 고를 수 있는 선수가 함께 온다', () {
      final draw = RoundDraw(byCondition: pool, random: Random(3));
      final drawn = draw.drawCondition(usedPlayerIds: {'a'});
      expect(drawn, isNotNull);
      expect(drawn!.pool.map((p) => p.id), isNot(contains('a')));
      expect(drawn.pool, isNotEmpty);
    });

    test('고를 선수가 한 명도 없는 구단은 뽑지 않는다', () {
      final draw = RoundDraw(
        byCondition: {
          const RoundCondition(teamId: 'db', teamName: '원주 DB'): [
            player(id: 'c'),
          ],
          const RoundCondition(teamId: 'sk', teamName: '서울 SK'): [
            player(id: 'd'),
          ],
        },
        random: Random(4),
      );
      for (var i = 0; i < 20; i++) {
        expect(
          draw.drawCondition(usedPlayerIds: {'c'})!.condition.teamId,
          'sk',
        );
      }
    });

    test('이미 라인업에 들어간 선수는 다시 나오지 않는다', () {
      final draw = RoundDraw(
        byCondition: {
          const RoundCondition(teamId: 'db', teamName: '원주 DB'): [
            player(id: 'c'),
          ],
        },
        random: Random(2),
      );
      expect(draw.draw(usedPlayerIds: {'c'}), isNull);
    });
  });
}
