import 'dart:math';

import 'package:basket_it/features/game540/game_54_0_rules.dart';
import 'package:basket_it/features/game540/models/game_54_0.dart';
import 'package:flutter_test/flutter_test.dart';

LegendPlayer player({
  String id = 'p1',
  String name = '선수',
  PlayerLine line = PlayerLine.guard,
  String teamId = 'sk',
  int era = 2010,
  double ppg = 10,
  double rpg = 3,
  double apg = 2,
  double spg = 0.5,
  double bpg = 0.2,
}) => LegendPlayer(
  id: id,
  name: name,
  line: line,
  teamId: teamId,
  era: era,
  season: '2015-2016',
  teamName: 'SK',
  games: 50,
  mpg: 30,
  ppg: ppg,
  rpg: rpg,
  apg: apg,
  spg: spg,
  bpg: bpg,
);

/// 리그를 지배한 급(서장훈 2001-02: 25.3점 10리바 1.7어시 수준).
LegendPlayer star(String id, PlayerLine line, LineupSlot _, {int era = 2010, String teamId = 'sk'}) =>
    player(id: id, line: line, era: era, teamId: teamId, ppg: 25, rpg: 10, apg: 5, spg: 1.5, bpg: 1);

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
    Map<LineupSlot, LegendPlayer> lineupOf(List<LegendPlayer> players) => {
      for (final (i, p) in players.indexed) LineupSlot.values[i]: p,
    };

    test('제자리에 선 최고 선수들은 54승에 가깝다', () {
      final result = simulate(
        lineupOf([
          star('1', PlayerLine.guard, LineupSlot.pg),
          star('2', PlayerLine.guard, LineupSlot.sg),
          star('3', PlayerLine.forward, LineupSlot.sf),
          star('4', PlayerLine.forward, LineupSlot.pf),
          star('5', PlayerLine.center, LineupSlot.c),
        ]),
      );
      expect(result.wins, greaterThan(45));
      expect(result.fitScore, 100);
    });

    test('같은 자리 재능도 엉뚱한 자리에 서면 승수가 깎인다', () {
      final sameTalent = [
        star('1', PlayerLine.center, LineupSlot.pg),
        star('2', PlayerLine.center, LineupSlot.sg),
        star('3', PlayerLine.center, LineupSlot.sf),
        star('4', PlayerLine.guard, LineupSlot.pf),
        star('5', PlayerLine.guard, LineupSlot.c),
      ];
      final wrong = simulate(lineupOf(sameTalent));
      expect(wrong.fitScore, lessThan(60));
      expect(wrong.wins, lessThan(45));
    });

    test('기록이 적은 선수만 모으면 승수가 낮다', () {
      final result = simulate(
        lineupOf([
          for (var i = 0; i < 5; i++)
            player(id: '$i', ppg: 4, rpg: 1, apg: 1, spg: 0.2, bpg: 0),
        ]),
      );
      expect(result.powerScore, lessThan(20));
      expect(result.wins, lessThan(15));
    });

    test('같은 팀·같은 시대를 함께한 선수끼리는 호흡 점수가 높다', () {
      final together = simulate(
        lineupOf([
          star('1', PlayerLine.guard, LineupSlot.pg, teamId: 'sk', era: 2010),
          star('2', PlayerLine.guard, LineupSlot.sg, teamId: 'sk', era: 2010),
          star('3', PlayerLine.forward, LineupSlot.sf, teamId: 'sk', era: 2010),
          star('4', PlayerLine.forward, LineupSlot.pf, teamId: 'sk', era: 2010),
          star('5', PlayerLine.center, LineupSlot.c, teamId: 'sk', era: 2010),
        ]),
      );
      final apart = simulate(
        lineupOf([
          star('1', PlayerLine.guard, LineupSlot.pg, teamId: 'sk', era: 1990),
          star('2', PlayerLine.guard, LineupSlot.sg, teamId: 'db', era: 2000),
          star('3', PlayerLine.forward, LineupSlot.sf, teamId: 'lg', era: 2010),
          star('4', PlayerLine.forward, LineupSlot.pf, teamId: 'kcc', era: 2020),
          star('5', PlayerLine.center, LineupSlot.c, teamId: 'kt', era: 2000),
        ]),
      );
      expect(together.synergyScore, 100);
      expect(apart.synergyScore, lessThan(together.synergyScore));
      expect(together.wins, greaterThan(apart.wins));
    });

    test('다섯 자리가 다 차기 전에는 0승', () {
      expect(simulate({LineupSlot.pg: player()}).wins, 0);
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
  });

  group('순위', () {
    test('더 많이 이길수록 앞 순위, 상위 %도 작아진다', () {
      const distribution = WinDistribution([10, 14, 20, 20, 31, 44]);
      expect(distribution.rankOf(50), 1);
      expect(distribution.rankOf(20), 3);
      expect(distribution.rankOf(0), 7);
    });

    test('무작위 라인업을 뽑아 분포를 만든다', () {
      final draw = RoundDraw(
        byCondition: {
          for (var team = 0; team < 6; team++)
            RoundCondition(teamId: 'team$team', era: 2010): [
              for (var i = 0; i < 4; i++)
                player(id: 'p$team$i', ppg: 5.0 + i * 4),
            ],
        },
        random: Random(7),
      );
      final distribution = WinDistribution.sample(draw, size: 50);
      expect(distribution.size, 50);
      expect(distribution.wins, isNot(contains(lessThan(0))));
      // 오름차순으로 정렬돼 있어야 순위를 셀 수 있다.
      for (var i = 1; i < distribution.wins.length; i++) {
        expect(distribution.wins[i], greaterThanOrEqualTo(distribution.wins[i - 1]));
      }
    });

    test('순위를 매기면 상위 %가 함께 나온다', () {
      const base = LineupResult(
        wins: 30,
        powerScore: 0,
        fitScore: 0,
        synergyScore: 0,
      );
      expect(base.topPercent, isNull);
      final ranked = base.withRank(rank: 25, rankPool: 1000);
      expect(ranked.wins, 30);
      expect(ranked.topPercent, closeTo(2.5, 0.001));
    });
  });

  group('라운드 뽑기', () {
    final pool = {
      const RoundCondition(teamId: 'sk', era: 2010): [
        player(id: 'a'),
        player(id: 'b'),
      ],
      const RoundCondition(teamId: 'db', era: 1990): [player(id: 'c')],
    };

    test('선수가 있는 조합에서만 뽑는다', () {
      final draw = RoundDraw(byCondition: pool, random: Random(1));
      for (var i = 0; i < 20; i++) {
        final drawn = draw.draw();
        expect(pool.keys, contains(drawn!.condition));
        expect(pool[drawn.condition]!.map((p) => p.id), contains(drawn.player.id));
      }
    });

    test('조건을 뽑으면 그 조건에서 고를 수 있는 선수가 함께 온다', () {
      final draw = RoundDraw(byCondition: pool, random: Random(3));
      final drawn = draw.drawCondition(usedPlayerIds: {'a'});
      expect(drawn, isNotNull);
      expect(drawn!.pool.map((p) => p.id), isNot(contains('a')));
      expect(drawn.pool, isNotEmpty);
    });

    test('고를 선수가 한 명도 없는 조합은 뽑지 않는다', () {
      final draw = RoundDraw(
        byCondition: {
          const RoundCondition(teamId: 'db', era: 1990): [player(id: 'c')],
          const RoundCondition(teamId: 'sk', era: 2010): [player(id: 'd')],
        },
        random: Random(4),
      );
      for (var i = 0; i < 20; i++) {
        expect(draw.drawCondition(usedPlayerIds: {'c'})!.condition.teamId, 'sk');
      }
    });

    test('이미 라인업에 들어간 선수는 다시 나오지 않는다', () {
      final draw = RoundDraw(
        byCondition: {
          const RoundCondition(teamId: 'db', era: 1990): [player(id: 'c')],
        },
        random: Random(2),
      );
      expect(draw.draw(usedPlayerIds: {'c'}), isNull);
    });
  });
}
