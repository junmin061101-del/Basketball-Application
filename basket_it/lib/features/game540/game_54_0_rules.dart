import 'dart:math';

import 'package:flutter/foundation.dart';

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

/// 라인업 점수. 전력·자리 적합·호흡과 그것을 합친 값(0~1).
@immutable
class LineupScore {
  final double power;
  final double fit;
  final double synergy;
  final double total;

  const LineupScore({
    required this.power,
    required this.fit,
    required this.synergy,
    required this.total,
  });
}

/// 라인업을 전력(62%) · 자리 적합(25%) · 호흡(13%)으로 점수 낸다.
LineupScore lineupScore(Map<LineupSlot, LegendPlayer> lineup) {
  final players = lineup.values.toList();
  if (players.isEmpty) {
    return const LineupScore(power: 0, fit: 0, synergy: 0, total: 0);
  }

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

  return LineupScore(
    power: power,
    fit: fit,
    synergy: synergy,
    total: power * 0.62 + fit * 0.25 + synergy * 0.13,
  );
}

/// 54승 0패가 되는 점수.
///
/// 잘 고른 판(명단에서 가장 좋은 선수를 골라 맞는 자리에 세우는 판) 3,000판의
/// 점수를 재 보고, 그 위쪽 5%가 닿는 값으로 정했다. 스무 판에 한 번쯤 54-0이
/// 나온다.
const perfectScore = 0.92;

/// 점수를 승률로 바꿀 때의 기울기. 클수록 잘해야 승수가 오른다.
const _winCurve = 3.0;

/// 완성된 라인업의 승수를 계산한다.
///
/// 아무리 못해도 프로 다섯 명이라 몇 경기는 이기고, 54승은 [perfectScore]에
/// 닿아야 한다. 잘 고르면 스무 판에 한 번쯤 나온다.
LineupResult simulate(Map<LineupSlot, LegendPlayer> lineup) {
  if (lineup.length < LineupSlot.values.length) {
    return const LineupResult(
      wins: 0,
      powerScore: 0,
      fitScore: 0,
      synergyScore: 0,
    );
  }

  final score = lineupScore(lineup);
  final reach = (score.total / perfectScore).clamp(0.0, 1.0);
  final ratio = 0.05 + 0.95 * pow(reach, _winCurve);
  final wins = (kbl54Games * ratio).round().clamp(0, kbl54Games);

  final players = lineup.values.toList();
  double sum(double Function(LegendPlayer) of) =>
      players.map(of).reduce((a, b) => a + b);

  return LineupResult(
    wins: wins,
    powerScore: score.power * 100,
    fitScore: score.fit * 100,
    synergyScore: score.synergy * 100,
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

/// 견줄 라인업을 만들 때 고르는 범위. 명단에서 좋은 쪽 다섯 명 중 하나를 뽑는다.
const _rivalPickFrom = 5;

/// 같은 규칙으로 만들어 본 라인업 [size]팀의 승수 분포.
///
/// 결과 화면의 "○○팀 중 몇 위"는 여기서 나온다. 기준이 될 다른 사람의 기록이
/// 없으니, 앱이 직접 라인업을 만들어 그 성적과 견준다. 아무나 막 고르면
/// 누구와 견줘도 1위가 나와서, 명단에서 좋은 쪽을 골라 자리까지 맞추는
/// (사람이 할 법한) 방식으로 만든다.
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
      while (lineup.length < slots.length) {
        final drawn = draw.drawCondition(
          usedConditions: conditions,
          usedPlayerIds: used,
        );
        if (drawn == null) break;
        conditions.add(drawn.condition);
        final sorted = [...drawn.pool]
          ..sort((a, b) => b.impact.compareTo(a.impact));
        final pick = sorted[rng.nextInt(min(_rivalPickFrom, sorted.length))];
        used.add(pick.id);
        // 자리는 제일 맞는 빈자리로.
        final open = slots.where((s) => !lineup.containsKey(s));
        final slot = open.reduce(
          (a, b) => slotFit(pick.line, b) > slotFit(pick.line, a) ? b : a,
        );
        lineup[slot] = pick;
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
