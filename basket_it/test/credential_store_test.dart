import 'package:basket_it/data/repositories/credential_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 보안 저장소 대신 쓰는 메모리 구현.
class _FakeStorage implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({required String key, dynamic iOptions, dynamic aOptions,
      dynamic lOptions, dynamic wOptions, dynamic mOptions, dynamic webOptions}) async =>
      data[key];

  @override
  Future<void> write({required String key, required String? value, dynamic iOptions,
      dynamic aOptions, dynamic lOptions, dynamic wOptions, dynamic mOptions,
      dynamic webOptions}) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, dynamic iOptions, dynamic aOptions,
      dynamic lOptions, dynamic wOptions, dynamic mOptions, dynamic webOptions}) async {
    data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('저장한 자격증명을 다시 불러온다', () async {
    final storage = _FakeStorage();
    final store = SecureCredentialStore(storage: storage);

    expect(await store.load(), isNull);

    await store.save(
      const SavedCredential(email: 'fan@basketit.app', password: 'pw123456'),
    );

    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.email, 'fan@basketit.app');
    expect(loaded.password, 'pw123456');
  });

  test('저장 해제하면 값이 지워진다', () async {
    final storage = _FakeStorage();
    final store = SecureCredentialStore(storage: storage);
    await store.save(const SavedCredential(email: 'a@b.com', password: 'pw123456'));

    await store.clear();

    expect(await store.load(), isNull);
    expect(storage.data, isEmpty);
  });

  test('이메일만 남아 있으면 불완전한 값으로 보고 무시한다', () async {
    final storage = _FakeStorage()..data['saved_email'] = 'a@b.com';
    final store = SecureCredentialStore(storage: storage);

    expect(await store.load(), isNull);
  });
}
