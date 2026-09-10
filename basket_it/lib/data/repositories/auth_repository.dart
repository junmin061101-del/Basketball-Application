import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/errors/auth_exception.dart';
import '../models/app_user.dart';

/// 인증을 추상화한 Repository.
///
/// 지금은 [FirebaseAuthRepository]가 Firebase Authentication(이메일/비밀번호)을
/// 사용하지만, 다른 인증 수단으로 바뀌어도 이 인터페이스를 구현하는 클래스
/// 하나만 교체하면 되도록 UI는 항상 [AuthRepository]에만 의존한다.
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;

  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signUp({required String email, required String password});

  /// 계정 없이 둘러보는 게스트(익명) 로그인.
  Future<AppUser> signInAnonymously();
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;

  FirebaseAuthRepository({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  AppUser _toAppUser(fb.User user) =>
      AppUser(uid: user.uid, email: user.email, isAnonymous: user.isAnonymous);

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map(
      (user) => user == null ? null : _toAppUser(user),
    );
  }

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _toAppUser(credential.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    }
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _toAppUser(credential.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    }
  }

  @override
  Future<AppUser> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return _toAppUser(credential.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
