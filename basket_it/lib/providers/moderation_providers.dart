import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/moderation_repository.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return DefaultModerationRepository();
});

/// 내가 차단한 사용자 목록. 차단/해제하면 목록 화면들이 곧바로 갱신된다.
class BlockedUsersNotifier extends StateNotifier<Set<String>> {
  final ModerationRepository _repo;

  BlockedUsersNotifier(this._repo) : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.loadBlockedUids();
  }

  Future<void> block(String uid) async {
    await _repo.blockUser(uid);
    state = {...state, uid};
  }

  Future<void> unblock(String uid) async {
    await _repo.unblockUser(uid);
    state = {...state}..remove(uid);
  }

  bool isBlocked(String uid) => state.contains(uid);
}

final blockedUsersProvider =
    StateNotifierProvider<BlockedUsersNotifier, Set<String>>((ref) {
      return BlockedUsersNotifier(ref.watch(moderationRepositoryProvider));
    });
