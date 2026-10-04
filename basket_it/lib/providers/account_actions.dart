import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/live_score_push.dart';
import 'auth_providers.dart';
import 'onboarding_providers.dart';

/// 탈퇴한 사람의 글에 남기는 표시. 개인정보처리방침에 적은 "비식별 처리"다.
const anonymousUid = 'deleted';
const anonymousName = '탈퇴한 사용자';

/// 글은 남기고 글쓴이만 지우는 곳. 지우면 남의 대화 맥락이 끊기기 때문이다.
const _publicWritings = [
  'communityPosts',
  'communityComments',
  'predictionComments',
];

/// 통째로 지우는 곳. 남이 볼 일 없는 내 기록이다.
const _privateRecords = ['predictionVotes'];

/// 회원 탈퇴. 내 기록을 정리한 뒤 계정을 지운다.
///
/// 계정을 먼저 지우면 로그인이 풀려 보안 규칙에 막히고 내 기록을 손댈 수 없다.
/// 그래서 순서가 중요하다: 글 비식별 → 기록 삭제 → 알림 구독 해제 → 계정 삭제.
Future<void> deleteAccount(WidgetRef ref, {FirebaseFirestore? firestore}) async {
  final uid = ref.read(authStateProvider).valueOrNull?.uid;
  final db = firestore ?? FirebaseFirestore.instance;

  if (uid != null) {
    for (final collection in _publicWritings) {
      final mine = await db
          .collection(collection)
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in mine.docs) {
        await doc.reference.update({
          'uid': anonymousUid,
          'displayName': anonymousName,
        });
      }
    }
    for (final collection in _privateRecords) {
      final mine = await db
          .collection(collection)
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in mine.docs) {
        await doc.reference.delete();
      }
    }
    // 팔로우한 팀·선수.
    await db.collection('users').doc(uid).delete();
  }

  // 잠금화면 알림을 받던 기기 등록(FCM 토큰)도 지운다.
  await LiveScorePushService.instance?.unsubscribe();

  await ref.read(authRepositoryProvider).deleteAccount();

  // 화면에 남아 있는 팔로우 표시도 비운다.
  ref.read(followedTeamIdsProvider.notifier).state = {};
  ref.read(followedPlayerIdsProvider.notifier).state = {};
}
