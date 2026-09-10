/// Firebase Authentication 오류를 사용자에게 보여줄 한국어 메시지로 변환한 예외.
class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  /// firebase_auth의 `FirebaseAuthException.code`를 한국어 메시지로 매핑한다.
  factory AuthException.fromCode(String code) {
    switch (code) {
      case 'invalid-email':
        return const AuthException('이메일 형식이 올바르지 않아요.');
      case 'user-disabled':
        return const AuthException('사용이 제한된 계정이에요.');
      case 'user-not-found':
        return const AuthException('가입되지 않은 이메일이에요.');
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthException('이메일 또는 비밀번호가 올바르지 않아요.');
      case 'email-already-in-use':
        return const AuthException('이미 가입된 이메일이에요.');
      case 'weak-password':
        return const AuthException('비밀번호가 너무 약해요. 6자 이상으로 설정해주세요.');
      case 'network-request-failed':
        return const AuthException('네트워크 연결을 확인해주세요.');
      case 'too-many-requests':
        return const AuthException('잠시 후 다시 시도해주세요.');
      default:
        return const AuthException('알 수 없는 오류가 발생했어요. 잠시 후 다시 시도해주세요.');
    }
  }

  @override
  String toString() => message;
}
