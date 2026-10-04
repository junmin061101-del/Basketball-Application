import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prediction.dart';

/// 승부예측(투표/토론) 데이터 접근을 추상화한 Repository.
///
/// 지금은 Firestore 구현 하나뿐이지만, 인터페이스를 두어 테스트용 목업이나
/// 다른 백엔드로 교체할 수 있게 한다.
abstract class PredictionRepository {
  /// 특정 경기의 투표를 실시간으로 구독한다.
  Stream<List<PredictionVote>> watchVotes(String gameId);

  /// 투표를 저장한다(같은 사용자가 다시 고르면 덮어쓴다).
  Future<void> submitVote(PredictionVote vote);

  /// 특정 경기의 토론 댓글을 실시간으로 구독한다(오래된 순).
  Stream<List<PredictionComment>> watchComments(String gameId);

  Future<void> addComment(PredictionComment comment);

  /// 랭킹 계산용 전체 투표.
  Future<List<PredictionVote>> getAllVotes();
}

class FirestorePredictionRepository implements PredictionRepository {
  final FirebaseFirestore _db;

  FirestorePredictionRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _votes =>
      _db.collection('predictionVotes');
  CollectionReference<Map<String, dynamic>> get _comments =>
      _db.collection('predictionComments');

  @override
  Stream<List<PredictionVote>> watchVotes(String gameId) {
    return _votes.where('gameId', isEqualTo: gameId).snapshots().map(
      (snap) => snap.docs
          .map((d) => PredictionVote.fromMap(d.data()))
          .whereType<PredictionVote>()
          .toList(),
    );
  }

  @override
  Future<void> submitVote(PredictionVote vote) {
    return _votes.doc(vote.docId).set({
      ...vote.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<PredictionComment>> watchComments(String gameId) {
    // gameId + createdAt 복합 인덱스 없이 쓰기 위해 정렬은 클라이언트에서 한다.
    return _comments.where('gameId', isEqualTo: gameId).snapshots().map((
      snap,
    ) {
      final list = snap.docs
          .map((d) => PredictionComment.fromMap(d.id, d.data()))
          .whereType<PredictionComment>()
          .toList();
      list.sort((a, b) {
        final ta = a.createdAt;
        final tb = b.createdAt;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1; // 서버 확인 전(방금 쓴 댓글)은 맨 뒤
        if (tb == null) return -1;
        return ta.compareTo(tb);
      });
      return list;
    });
  }

  @override
  Future<void> addComment(PredictionComment comment) {
    return _comments.add({
      ...comment.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<PredictionVote>> getAllVotes() async {
    final snap = await _votes.get();
    return snap.docs
        .map((d) => PredictionVote.fromMap(d.data()))
        .whereType<PredictionVote>()
        .toList();
  }
}
