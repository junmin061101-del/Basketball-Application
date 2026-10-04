import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/name_mask.dart';
import '../data/repositories/user_profile_repository.dart';
import 'auth_providers.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return FirestoreUserProfileRepository();
});

/// 지금 로그인한 사람이 정해 둔 닉네임. 아직 안 정했으면 null.
final nicknameProvider = AsyncNotifierProvider<NicknameController, String?>(
  NicknameController.new,
);

class NicknameController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) return null;
    return ref.read(userProfileRepositoryProvider).loadNickname(uid);
  }

  /// 닉네임을 저장한다. 로그인 상태가 아니면 아무것도 하지 않는다.
  Future<void> save(String nickname) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref
        .read(userProfileRepositoryProvider)
        .saveNickname(uid: uid, nickname: nickname);
    state = AsyncData(nickname);
  }
}

/// 글·댓글·예측에 남길 이름.
///
/// 정해 둔 닉네임이 있으면 그대로 쓰고, 없으면 이메일에서 만든 이름을
/// 가려서 쓴다. 공용 컬렉션에 원본 이름이 남지 않도록 저장 시점에 정한다.
String resolveDisplayName({
  required String? nickname,
  required String fallback,
}) {
  final name = nickname?.trim() ?? '';
  return name.isEmpty ? maskDisplayName(fallback) : name;
}

/// 글을 올리기 직전에 쓸 이름.
///
/// 닉네임을 아직 못 읽었을 수 있어서(앱을 켜자마자 글을 쓰는 경우) 읽기를
/// 기다린 뒤에 정한다. 화면에 보여 주기만 할 때는 [displayNameProvider]를 쓴다.
Future<String> readDisplayName(WidgetRef ref) async {
  final user = ref.read(authStateProvider).valueOrNull;
  final nickname = await ref.read(nicknameProvider.future);
  return resolveDisplayName(
    nickname: nickname,
    fallback: user?.displayName ?? '',
  );
}

/// 지금 로그인한 사람이 글에 남길 이름(화면 표시용).
final displayNameProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return resolveDisplayName(
    nickname: ref.watch(nicknameProvider).valueOrNull,
    fallback: user?.displayName ?? '',
  );
});
