import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/game_54_0.dart';

/// 54-0 게임이 쓰는 역대 KBL 선수 명단.
///
/// `tools/build-54-0-players.js`가 KBL 공식 기록(1997년 원년부터)에서 만들어
/// 둔 파일을 읽는다. 선수도 기록도 지어내지 않고, 그 시즌에 실제로 뛴 선수와
/// 경기당 평균만 담겨 있다.
class LegendPlayerRepository {
  static const assetPath = 'assets/game/kbl_players_54_0.json';

  List<LegendPlayer>? _cache;

  Future<List<LegendPlayer>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = jsonDecode(await rootBundle.loadString(assetPath));
    final rows = raw is Map ? raw['players'] : null;
    final players = rows is List
        ? rows
              .whereType<Map>()
              .map(LegendPlayer.fromMap)
              .whereType<LegendPlayer>()
              .toList()
        : <LegendPlayer>[];
    return _cache = players;
  }
}

/// [players]를 [구단 · 시대]로 묶는다.
///
/// 한 번도 그 시대에 없던 구단(수원 KT는 2001년 창단)이 뽑히지 않도록,
/// 선수가 있는 조합만 남긴다.
Map<RoundCondition, List<LegendPlayer>> groupByCondition(
  List<LegendPlayer> players,
) {
  final byCondition = <RoundCondition, List<LegendPlayer>>{};
  for (final player in players) {
    final key = RoundCondition(teamId: player.teamId, era: player.era);
    byCondition.putIfAbsent(key, () => []).add(player);
  }
  return byCondition;
}
