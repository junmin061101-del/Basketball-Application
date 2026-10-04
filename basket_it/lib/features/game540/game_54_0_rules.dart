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

  return LineupResult(
    wins: wins,
    powerScore: power * 100,
    fitScore: fit * 100,
    synergyScore: synergy * 100,
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

  ({RoundCondition condition, LegendPlayer player})? draw({
    Set<RoundCondition> usedConditions = const {},
    Set<String> usedPlayerIds = const {},
  }) {
    final pool = byCondition.entries
        .where((e) => !usedConditions.contains(e.key))
        .toList();
    final from = pool.isEmpty ? byCondition.entries.toList() : pool;
    if (from.isEmpty) return null;

    final entry = from[random.nextInt(from.length)];
    final candidates = entry.value
        .where((p) => !usedPlayerIds.contains(p.id))
        .toList();
    if (candidates.isEmpty) return null;
    return (
      condition: entry.key,
      player: candidates[random.nextInt(candidates.length)],
    );
  }
}
