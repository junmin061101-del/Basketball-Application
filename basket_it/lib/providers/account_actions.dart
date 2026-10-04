import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'onboarding_providers.dart';

/// 회원 탈퇴할 때 내 기록을 지우는 곳(컬렉션 → 내 것을 가리키는 필드).
///
/// 커뮤니티 글·댓글은 여기서 지우지 않는다. 대화 맥락이 끊기기 때문이며,
/// 개인정보처리방침에도 그렇게 적어 두었다(원하면 탈퇴 전에 직접 지운다).
const _myDataCollections = {
  'predictionVotes': 'uid',
  'predictionComments': 'uid',
};

/// 회원 탈퇴. 내 기록을 지운 뒤 계정을 지운다.
///
/// 계정을 먼저 지우면 로그인이 풀려 Firestore 보안 규칙에 막혀 내 기록을
/// 지울 수 없다. 그래서 순서가 중요하다.
Future<void> deleteAccount(WidgetRef ref, {FirebaseFirestore? firestore}) async {
  final uid = ref.read(authStateProvider).valueOrNull?.uid;
  final db = firestore ?? FirebaseFirestore.instance;

  if (uid != null) {
    for (final entry in _myDataCollections.entries) {
      final mine = await db
          .collection(entry.key)
          .where(entry.value, isEqualTo: uid)
          .get();
      for (final doc in mine.docs) {
        await doc.reference.delete();
      }
    }
    // 팔로우한 팀·선수.
    await db.collection('users').doc(uid).delete();
  }

  await ref.read(authRepositoryProvider).deleteAccount();

  // 화면에 남아 있는 팔로우 표시도 비운다.
  ref.read(followedTeamIdsProvider.notifier).state = {};
  ref.read(followedPlayerIdsProvider.notifier).state = {};
}
