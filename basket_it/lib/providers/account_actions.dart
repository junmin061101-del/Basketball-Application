import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/live_score_push.dart';
import 'auth_providers.dart';
import 'onboarding_providers.dart';

/// 회원 탈퇴. 앱은 알림 구독을 끊고 Auth 계정만 지운다.
///
/// 글 비식별·투표 삭제·좋아요와 신고 정리는 계정이 지워지면 서버
/// (functions/account-cleanup.js)가 한다. 전에는 앱이 데이터를 먼저 지우고
/// 계정을 지웠는데, 계정 삭제가 "최근 로그인 필요"로 막히면 데이터만
/// 지워진 채 계정이 남았다. 이제 계정 삭제가 실패하면 아무것도 바뀌지 않는다.
Future<void> deleteAccount(WidgetRef ref) async {
  // 잠금화면 알림을 받던 기기 등록(FCM 토큰)은 서버가 사용자와 연결해 두지
  // 않으므로 여기서 지운다.
  await LiveScorePushService.instance?.unsubscribe();

  await ref.read(authRepositoryProvider).deleteAccount();

  // 화면에 남아 있는 팔로우 표시도 비운다.
  ref.read(followedTeamIdsProvider.notifier).state = {};
  ref.read(followedPlayerIdsProvider.notifier).state = {};
}
