import 'dart:math';

import 'models/game_54_0.dart';

/// 한 시즌 54경기. KBL 정규리그 경기 수이자 이 게임의 만점이다.
const kbl54Games = 54;

/// 자리 적합도(0~1).
///
/// KBL은 선수를 가드·포워드·센터로만 나눈다. 가드를 센터 자리에 세우면
/// 제 몫을 못 하는 정도를 숫자로 둔 것이다.
double slotFit(PlayerLine line, LineupSlot slot) {
  switch (line) {
    case PlayerLine.guard:
      return switch (slot) {
        LineupSlot.pg || LineupSlot.sg => 1.0,
        LineupSlot.sf => 0.7,
        LineupSlot.pf => 0.4,
        LineupSlot.c => 0.25,
      };
    case PlayerLine.forward:
      return switch (slot) {
        LineupSlot.sf || LineupSlot.pf => 1.0,
        LineupSlot.sg => 0.75,
        LineupSlot.c => 0.6,
        LineupSlot.pg => 0.4,
      };
    case PlayerLine.center:
      return switch (slot) {
        LineupSlot.c => 1.0,
        LineupSlot.pf => 0.85,
        LineupSlot.sf => 0.5,
        LineupSlot.sg => 0.3,
        LineupSlot.pg => 0.2,
      };
  }
}

/// 선수 한 명의 전력(0~1). 경기당 기록으로만 매긴다.
///
/// 리그를 지배한 선수(영향력 42쯤)가 1, 벤치에서 짧게 뛴 선수(12쯤)가 0이다.
double playerPower(LegendPlayer player) =>
    ((player.impact - 12) / (42 - 12)).clamp(0.0, 1.0);

/// 함께 뛴 사이인가. 같은 구단·같은 시대면 손발이 맞는다고 본다.
double _pairSynergy(LegendPlayer a, LegendPlayer b) {
  if (a.teamId == b.teamId && a.era == b.era) return 1.0;
  if (a.era == b.era) return 0.4;
  if (a.teamId == b.teamId) return 0.3;
  return 0.0;
}

/// 완성된 라인업의 승수를 계산한다.
///
/// 전력(62%) · 자리 적합(25%) · 호흡(13%)을 더해 54경기로 환산한다. 아무리
/// 못해도 프로 다섯 명이라 몇 경기는 이기고, 54승은 셋 다 만점에 가까워야 한다.
LineupResult simulate(Map<LineupSlot, LegendPlayer> lineup) {
  if (lineup.length < LineupSlot.values.length) {
    return const LineupResult(
      wins: 0,
      powerScore: 0,
      fitScore: 0,
      synergyScore: 0,
    );
  }

  final players = lineup.values.toList();
  final power =
      players.map(playerPower).reduce((a, b) => a + b) / players.length;

  var fitTotal = 0.0;
  lineup.forEach((slot, player) => fitTotal += slotFit(player.line, slot));
  final fit = fitTotal / lineup.length;

  var pairTotal = 0.0;
  for (var i = 0; i < players.length; i++) {
    for (var j = i + 1; j < players.length; j++) {
      pairTotal += _pairSynergy(players[i], players[j]);
    }
  }
  // 손발 맞는 짝 셋이면 만점으로 본다(열 짝 모두는 사실상 불가능하다).
  final synergy = (pairTotal / 3).clamp(0.0, 1.0);

  final total = power * 0.62 + fit * 0.25 + synergy * 0.13;
  final ratio = 0.05 + 0.95 * pow(total, 1.5);
  final wins = (kbl54Games * ratio).round().clamp(0, kbl54Games);

  double sum(double Function(LegendPlayer) of) =>
      players.map(of).reduce((a, b) => a + b);

  return LineupResult(
    wins: wins,
    powerScore: power * 100,
    fitScore: fit * 100,
    synergyScore: synergy * 100,
    ppg: sum((p) => p.ppg),
    rpg: sum((p) => p.rpg),
    apg: sum((p) => p.apg),
    spg: sum((p) => p.spg),
    bpg: sum((p) => p.bpg),
  );
}

/// 라운드 조건과 그 조건에 맞는 선수를 뽑는다.
///
/// 선수가 한 명도 없는 조합(1990년대 수원 KT는 창단 전이다)은 아예 뽑지 않고,
/// 이미 라인업에 들어간 선수와 이번 게임에서 이미 나온 조건도 피한다.
class RoundDraw {
  final Map<RoundCondition, List<LegendPlayer>> byCondition;
  final Random random;

  RoundDraw({required this.byCondition, Random? random})
    : random = random ?? Random();

  /// 뽑을 것이 있는지.
  bool get isEmpty => byCondition.isEmpty;

  /// 이번 라운드의 조건 하나와, 그 조건에서 아직 고를 수 있는 선수들을 준다.
  ({RoundCondition condition, List<LegendPlayer> pool})? drawCondition({
    Set<RoundCondition> usedConditions = const {},
    Set<String> usedPlayerIds = const {},
  }) {
    final pool = byCondition.entries
        .where((e) => !usedConditions.contains(e.key))
        .toList();
    final from = (pool.isEmpty ? byCondition.entries.toList() : pool)
        .map(
          (e) => (
            condition: e.key,
            pool: e.value
                .where((p) => !usedPlayerIds.contains(p.id))
                .toList(growable: false),
          ),
        )
        .where((e) => e.pool.isNotEmpty)
        .toList();
    if (from.isEmpty) return null;
    return from[random.nextInt(from.length)];
  }

  ({RoundCondition condition, LegendPlayer player})? draw({
    Set<RoundCondition> usedConditions = const {},
    Set<String> usedPlayerIds = const {},
  }) {
    final drawn = drawCondition(
      usedConditions: usedConditions,
      usedPlayerIds: usedPlayerIds,
    );
    if (drawn == null) return null;
    return (
      condition: drawn.condition,
      player: drawn.pool[random.nextInt(drawn.pool.length)],
    );
  }
}

/// 아무렇게나 만든 라인업 [size]팀의 승수 분포.
///
/// 결과 화면의 "○○팀 중 몇 위"는 여기서 나온다. 기준이 될 다른 사람의 기록이
/// 없으니, 같은 규칙으로 무작위 라인업을 만들어 그 성적과 견준다.
class WinDistribution {
  /// 오름차순으로 정렬한 승수.
  final List<int> wins;

  const WinDistribution(this.wins);

  int get size => wins.length;

  /// 같은 명단에서 무작위 라인업 [size]팀을 만들어 승수를 모은다.
  factory WinDistribution.sample(
    RoundDraw draw, {
    int size = 1000,
    Random? random,
  }) {
    final rng = random ?? Random(54);
    final slots = LineupSlot.values;
    final collected = <int>[];
    for (var i = 0; i < size; i++) {
      final lineup = <LineupSlot, LegendPlayer>{};
      final used = <String>{};
      final conditions = <RoundCondition>{};
      final order = [...slots]..shuffle(rng);
      for (final slot in order) {
        final drawn = draw.draw(
          usedConditions: conditions,
          usedPlayerIds: used,
        );
        if (drawn == null) break;
        conditions.add(drawn.condition);
        used.add(drawn.player.id);
        lineup[slot] = drawn.player;
      }
      if (lineup.length == slots.length) collected.add(simulate(lineup).wins);
    }
    collected.sort();
    return WinDistribution(collected);
  }

  /// 같은 표본을 몇 번에 나눠 만든다.
  ///
  /// 1,000팀을 한 번에 돌리면 0.7초쯤 걸려 화면이 멎는다. 게임을 시작할 때
  /// 조금씩 미리 만들어 두면, 결과를 낼 때는 이미 준비돼 있다.
  static Future<WinDistribution> sampleSpread(
    RoundDraw draw, {
    int size = 1000,
    int chunk = 25,
    Random? random,
  }) async {
    final rng = random ?? Random(54);
    final collected = <int>[];
    for (var done = 0; done < size; done += chunk) {
      collected.addAll(
        WinDistribution.sample(
          draw,
          size: min(chunk, size - done),
          random: rng,
        ).wins,
      );
      await Future<void>.delayed(Duration.zero);
    }
    collected.sort();
    return WinDistribution(collected);
  }

  /// [wins]승이 몇 위인가. 더 많이 이긴 라인업 수 + 1위다.
  int rankOf(int target) {
    var better = 0;
    for (var i = wins.length - 1; i >= 0; i--) {
      if (wins[i] <= target) break;
      better++;
    }
    return better + 1;
  }
}
