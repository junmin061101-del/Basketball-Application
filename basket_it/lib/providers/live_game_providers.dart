import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/live_game_state.dart';

/// 지금 진행 중인 경기들의 실시간 상태(경기 키 → 상태).
///
/// 서버가 30초마다 Firestore에 적어 두는 값을 그대로 받아 본다. 정적 JSON은
/// 20분에 한 번 올라와서 경기 중 점수가 한참 늦는데, 이 스트림이 그 사이를
/// 메운다. Firebase가 없는 환경(테스트)이나 읽기에 실패하면 빈 맵이라
/// 화면은 정적 JSON만으로도 그대로 돈다.
final liveGameStatesProvider = StreamProvider<Map<String, LiveGameState>>((
  ref,
) {
  if (Firebase.apps.isEmpty) {
    return Stream.value(const <String, LiveGameState>{});
  }
  // 오늘 열린 경기만 본다. 지난 경기 문서까지 받아올 이유가 없다.
  final since = DateTime.now().subtract(const Duration(hours: 12));
  return FirebaseFirestore.instance
      .collection('liveGames')
      .where('updatedAt', isGreaterThan: since.millisecondsSinceEpoch)
      .snapshots()
      .map((snapshot) {
        final states = <String, LiveGameState>{};
        for (final doc in snapshot.docs) {
          final state = LiveGameState.fromDoc(doc.id, doc.data());
          if (state != null) states[doc.id] = state;
        }
        return states;
      })
      .handleError((Object error) {
        // 로그인 전이거나 규칙에 막히면 실시간 값 없이 지낸다.
        debugPrint('실시간 경기 상태를 받지 못했습니다: $error');
      });
});
