import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/game.dart';
import '../data/models/player_game_stats.dart';
import 'repository_providers.dart';

/// 진행 중인 경기의 선수 기록(서버가 30초마다 Firestore에 적어 둔다).
///
/// 정적 JSON은 20분에 한 번 올라와서, 경기가 시작하고 한참 동안 기록이
/// 비어 있었다. 경기 중에는 이쪽을 보여준다.
final liveBoxScoreProvider =
    StreamProvider.family<List<PlayerGameStats>, Game>((ref, game) {
      if (Firebase.apps.isEmpty) {
        return Stream.value(const <PlayerGameStats>[]);
      }
      final key = '${ref.watch(selectedLeagueProvider).wireName}:${game.id}';
      return FirebaseFirestore.instance
          .collection('liveBoxScores')
          .doc(key)
          .snapshots()
          .map((snapshot) {
            final rows = snapshot.data()?['lines'];
            if (rows is! List) return const <PlayerGameStats>[];
            return rows
                .whereType<Map>()
                .map((row) => PlayerGameStats.fromMap(row, game.id))
                .toList();
          })
          .handleError((Object error) {
            debugPrint('진행 중인 경기 기록을 받지 못했습니다: $error');
          });
    });

/// 화면에 보여줄 선수 기록을 고른다.
///
/// 끝난 경기는 수집기가 올린 기록이 최종이므로 그것을 쓰고, 아직 안 올라왔으면
/// (경기 직후 20분 남짓) 서버가 적어 둔 것으로 메운다. 진행 중인 경기는 반대로
/// 지금 기록이 먼저다.
List<PlayerGameStats> chooseBoxScore({
  required List<PlayerGameStats> stored,
  required List<PlayerGameStats> live,
  required GameStatus status,
}) {
  if (status == GameStatus.finished) {
    return stored.isNotEmpty ? stored : live;
  }
  return live.isNotEmpty ? live : stored;
}
