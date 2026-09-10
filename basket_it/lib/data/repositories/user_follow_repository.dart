import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_follows.dart';

/// 사용자별 팔로우(팀/선수) 저장을 추상화한 Repository.
///
/// "가장 많이 팔로우된 선수" 정렬은 스펙상 지금은 목업 집계값
/// ([PlayerRepository.getPlayersSortedByFollowers])을 그대로 사용하고,
/// 여기서는 로그인한 사용자 개인의 팔로우 선택만 Firestore에 저장/복원한다.
/// 나중에 실제 전체 집계로 전환할 때도 이 인터페이스는 그대로 두고
/// 구현체만 교체하면 된다.
abstract class UserFollowRepository {
  Future<void> saveFollows({
    required String uid,
    required Set<String> teamIds,
    required Set<String> playerIds,
  });

  Future<UserFollows> loadFollows(String uid);
}

class FirestoreUserFollowRepository implements UserFollowRepository {
  final FirebaseFirestore _db;

  FirestoreUserFollowRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> saveFollows({
    required String uid,
    required Set<String> teamIds,
    required Set<String> playerIds,
  }) async {
    await _db.collection('users').doc(uid).set({
      'followedTeamIds': teamIds.toList(),
      'followedPlayerIds': playerIds.toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<UserFollows> loadFollows(String uid) async {
    final snapshot = await _db.collection('users').doc(uid).get();
    final data = snapshot.data();
    if (data == null) return const UserFollows();
    return UserFollows(
      teamIds: Set<String>.from(
        (data['followedTeamIds'] as List?) ?? const [],
      ),
      playerIds: Set<String>.from(
        (data['followedPlayerIds'] as List?) ?? const [],
      ),
    );
  }
}
