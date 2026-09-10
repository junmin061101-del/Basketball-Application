import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'onboarding_providers.dart';

/// 팀/선수 팔로우를 토글하고, 로그인 상태면 즉시 Firestore에 반영한다.
/// 탐색 탭(팀 정보/선수 정보), 선수 상세 화면 등 여러 곳에서 공용으로 쓴다.
void toggleTeamFollow(WidgetRef ref, String teamId) {
  final current = ref.read(followedTeamIdsProvider);
  final next = {...current};
  if (next.contains(teamId)) {
    next.remove(teamId);
  } else {
    next.add(teamId);
  }
  ref.read(followedTeamIdsProvider.notifier).state = next;
  _persist(ref, teamIds: next, playerIds: ref.read(followedPlayerIdsProvider));
}

void togglePlayerFollow(WidgetRef ref, String playerId) {
  final current = ref.read(followedPlayerIdsProvider);
  final next = {...current};
  if (next.contains(playerId)) {
    next.remove(playerId);
  } else {
    next.add(playerId);
  }
  ref.read(followedPlayerIdsProvider.notifier).state = next;
  _persist(ref, teamIds: ref.read(followedTeamIdsProvider), playerIds: next);
}

void _persist(
  WidgetRef ref, {
  required Set<String> teamIds,
  required Set<String> playerIds,
}) {
  final uid = ref.read(authStateProvider).valueOrNull?.uid;
  if (uid == null) return;
  ref.read(userFollowRepositoryProvider).saveFollows(
    uid: uid,
    teamIds: teamIds,
    playerIds: playerIds,
  );
}
