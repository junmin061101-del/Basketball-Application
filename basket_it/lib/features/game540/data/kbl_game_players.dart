import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/game_54_0.dart';

/// 54-0 게임이 쓰는 선수 명단.
///
/// `tools/build-54-0-players.js`가 KBL 공식 기록에서 만들어 둔 파일을 읽는다.
/// 지금 KBL 10개 구단과 지금 뛰는 선수만 들어 있고, 기록은 제대로 치른 가장
/// 최근 시즌의 경기당 평균이다. 선수도 기록도 지어내지 않는다.
class GamePlayerRepository {
  static const assetPath = 'assets/game/kbl_players_54_0.json';

  List<GamePlayer>? _cache;

  Future<List<GamePlayer>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = jsonDecode(await rootBundle.loadString(assetPath));
    final rows = raw is Map ? raw['players'] : null;
    final players = rows is List
        ? rows
              .whereType<Map>()
              .map(GamePlayer.fromMap)
              .whereType<GamePlayer>()
              .toList()
        : <GamePlayer>[];
    return _cache = players;
  }
}

/// 고를 선수가 이보다 적은 구단은 라운드로 내지 않는다.
const _minPoolSize = 3;

/// [players]를 구단별로 묶는다. 룰렛은 이 구단들 중 하나를 뽑는다.
Map<RoundCondition, List<GamePlayer>> groupByCondition(
  List<GamePlayer> players,
) {
  final byCondition = <RoundCondition, List<GamePlayer>>{};
  for (final player in players) {
    final key = RoundCondition(
      teamId: player.teamId,
      teamName: player.teamName,
    );
    byCondition.putIfAbsent(key, () => []).add(player);
  }
  byCondition.removeWhere((_, pool) => pool.length < _minPoolSize);
  return byCondition;
}
