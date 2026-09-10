import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/credential_store.dart';
import '../data/repositories/user_follow_repository.dart';

/// Repository 구현체 주입 지점.
/// 실제 인증/저장 수단이 바뀌어도 이 두 줄만 교체하면 앱 전체가 바뀐다.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final userFollowRepositoryProvider = Provider<UserFollowRepository>((ref) {
  return FirestoreUserFollowRepository();
});

/// 로그인 화면의 "아이디·비밀번호 저장"용 보안 저장소.
final credentialStoreProvider = Provider<CredentialStore>((ref) {
  return SecureCredentialStore();
});

/// 저장된 자격증명(없으면 null). 로그인 화면 진입 시 자동으로 채워 넣는다.
final savedCredentialProvider = FutureProvider<SavedCredential?>((ref) {
  return ref.watch(credentialStoreProvider).load();
});

/// 로그인 상태 스트림. null이면 로그아웃 상태.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
