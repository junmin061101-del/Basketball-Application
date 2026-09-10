import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 로그인 화면에 자동으로 채워 넣을 저장된 자격증명.
class SavedCredential {
  final String email;
  final String password;

  const SavedCredential({required this.email, required this.password});
}

/// "아이디·비밀번호 저장" 기능의 저장소를 추상화한다.
///
/// 비밀번호는 일반 저장소(SharedPreferences 등)에 평문으로 두면 위험하므로
/// 기기의 보안 저장소(iOS Keychain / Android EncryptedSharedPreferences /
/// 웹 WebCrypto)에 넣는다.
abstract class CredentialStore {
  Future<SavedCredential?> load();
  Future<void> save(SavedCredential credential);
  Future<void> clear();
}

class SecureCredentialStore implements CredentialStore {
  static const _emailKey = 'saved_email';
  static const _passwordKey = 'saved_password';

  final FlutterSecureStorage _storage;

  // v11부터 Android는 기본으로 AES-GCM 암호화 저장이라 별도 옵션이 필요 없다.
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<SavedCredential?> load() async {
    try {
      final email = await _storage.read(key: _emailKey);
      final password = await _storage.read(key: _passwordKey);
      if (email == null || password == null) return null;
      return SavedCredential(email: email, password: password);
    } catch (_) {
      // 보안 저장소를 쓸 수 없는 환경이면 자동 완성만 포기하고 계속 진행한다.
      return null;
    }
  }

  @override
  Future<void> save(SavedCredential credential) async {
    try {
      await _storage.write(key: _emailKey, value: credential.email);
      await _storage.write(key: _passwordKey, value: credential.password);
    } catch (_) {
      // 저장 실패가 로그인 자체를 막지는 않도록 조용히 넘어간다.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _emailKey);
      await _storage.delete(key: _passwordKey);
    } catch (_) {}
  }
}
