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
