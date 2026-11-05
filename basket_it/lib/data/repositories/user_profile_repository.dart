import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자가 직접 정한 이름(닉네임)을 맡는다.
///
/// 팔로우와 같은 `users/{uid}` 문서에 `nickname` 한 칸으로 둔다. 이 이름은
/// 글을 쓸 때 글 문서에 함께 저장돼(공용 컬렉션에서 다시 읽지 않는다)
/// 커뮤니티·예측·랭킹에 그대로 보인다.
abstract class UserProfileRepository {
  /// 정해 둔 닉네임. 아직 없으면 null.
  Future<String?> loadNickname(String uid);

  Future<void> saveNickname({required String uid, required String nickname});

  /// 지금 판([termsVersion])의 약관에 동의했는지.
  Future<bool> hasAgreedTerms(String uid);

  Future<void> agreeTerms(String uid);
}

/// 약관 판. 약관을 크게 바꿔 다시 동의를 받아야 하면 올린다.
const termsVersion = 1;

class FirestoreUserProfileRepository implements UserProfileRepository {
  final FirebaseFirestore _db;

  FirestoreUserProfileRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<String?> loadNickname(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).get();
    final value = snapshot.data()?['nickname'];
    if (value is! String) return null;
    final name = value.trim();
    return name.isEmpty ? null : name;
  }

  @override
  Future<bool> hasAgreedTerms(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).get();
    final agreed = snapshot.data()?['termsVersion'];
    return agreed is num && agreed >= termsVersion;
  }

  @override
  Future<void> agreeTerms(String uid) async {
    await _db.collection('users').doc(uid).set({
      'termsVersion': termsVersion,
      'termsAgreedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> saveNickname({
    required String uid,
    required String nickname,
  }) async {
    await _db.collection('users').doc(uid).set({
      'nickname': nickname,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
