import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/moderation.dart';

/// 신고 접수와 사용자 차단을 담당한다.
///
/// - 신고: Firestore `reports` 컬렉션에 쌓아 운영자가 확인한다.
/// - 차단: 차단 목록은 개인 설정이라 기기에 저장하고, 화면에서 즉시 숨긴다.
///   (서버에 두면 다른 사람이 누가 누구를 차단했는지 볼 수 있어 좋지 않다)
abstract class ModerationRepository {
  Future<void> submitReport(Report report);

  /// 내가 차단한 사용자 uid 목록.
  Future<Set<String>> loadBlockedUids();
  Future<void> blockUser(String uid);
  Future<void> unblockUser(String uid);
}

class DefaultModerationRepository implements ModerationRepository {
  static const _blockedKey = 'blocked_uids';

  final FirebaseFirestore? _injectedDb;
  final FlutterSecureStorage _storage;

  DefaultModerationRepository({
    FirebaseFirestore? firestore,
    FlutterSecureStorage? storage,
  }) : _injectedDb = firestore,
       _storage = storage ?? const FlutterSecureStorage();

  /// 차단 목록은 기기에만 저장하므로, Firestore는 신고를 보낼 때만 필요하다.
  /// 생성자에서 미리 붙잡으면 Firebase 초기화 없이는 차단 기능도 못 쓰게 된다.
  FirebaseFirestore get _db => _injectedDb ?? FirebaseFirestore.instance;

  @override
  Future<void> submitReport(Report report) {
    return _db.collection('reports').doc(report.docId).set({
      ...report.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Set<String>> loadBlockedUids() async {
    try {
      final raw = await _storage.read(key: _blockedKey);
      if (raw == null || raw.isEmpty) return {};
      return raw.split(',').where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> blockUser(String uid) async {
    final current = await loadBlockedUids();
    await _write({...current, uid});
  }

  @override
  Future<void> unblockUser(String uid) async {
    final current = await loadBlockedUids()
      ..remove(uid);
    await _write(current);
  }

  Future<void> _write(Set<String> uids) async {
    try {
      await _storage.write(key: _blockedKey, value: uids.join(','));
    } catch (_) {
      // 저장소를 못 쓰는 환경이면 이번 세션에서만 적용된다.
    }
  }
}
