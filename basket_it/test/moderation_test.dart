import 'package:basket_it/data/models/moderation.dart';
import 'package:basket_it/data/repositories/moderation_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('신고 문서 id는 대상+신고자 조합이라 중복 신고가 쌓이지 않는다', () {
    const report = Report(
      targetId: 'post1',
      targetType: ReportTargetType.post,
      targetUid: 'author',
      reporterUid: 'me',
      reason: ReportReason.abuse,
    );
    expect(report.docId, 'post1_me');
    expect(report.toMap()['status'], 'pending');
    expect(report.toMap()['reason'], 'abuse');
  });

  test('차단은 저장되고 다시 불러온다', () async {
    final storage = _FakeStorage();
    final repo = DefaultModerationRepository(storage: storage);

    expect(await repo.loadBlockedUids(), isEmpty);

    await repo.blockUser('bad-user');
    await repo.blockUser('another');

    expect(await repo.loadBlockedUids(), {'bad-user', 'another'});
  });

  test('차단 해제하면 목록에서 빠진다', () async {
    final storage = _FakeStorage();
    final repo = DefaultModerationRepository(storage: storage);
    await repo.blockUser('a');
    await repo.blockUser('b');

    await repo.unblockUser('a');

    expect(await repo.loadBlockedUids(), {'b'});
  });

  test('같은 사용자를 두 번 차단해도 한 번만 저장된다', () async {
    final repo = DefaultModerationRepository(storage: _FakeStorage());
    await repo.blockUser('dup');
    await repo.blockUser('dup');
    expect(await repo.loadBlockedUids(), {'dup'});
  });
}
