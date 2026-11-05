import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prediction.dart';

/// 승부예측(투표/토론) 데이터 접근을 추상화한 Repository.
///
/// 지금은 Firestore 구현 하나뿐이지만, 인터페이스를 두어 테스트용 목업이나
/// 다른 백엔드로 교체할 수 있게 한다.
abstract class PredictionRepository {
  /// 특정 경기의 홈·원정 투표 수(서버가 센다). 아직 없으면 (0, 0).
  Stream<({int home, int away})> watchTally(String gameId);

  /// 내 투표. 아직 안 했으면 null.
  Stream<PredictionVote?> watchMyVote({
    required String gameId,
    required String uid,
  });

  /// 투표를 저장한다(같은 사용자가 다시 고르면 덮어쓴다).
  Future<void> submitVote(PredictionVote vote);

  /// 특정 경기의 토론 댓글을 실시간으로 구독한다(오래된 순).
  Stream<List<PredictionComment>> watchComments(String gameId);

  Future<void> addComment(PredictionComment comment);

  /// 서버가 채점해 둔 랭킹(맞힌 수 → 이름 순).
  Future<List<LeaderboardEntry>> getLeaderboard();
}

/// 댓글 목록이 한 번에 받는 수. 보안 규칙이 이보다 큰 목록 읽기를 막는다.
const commentPageSize = 500;

class FirestorePredictionRepository implements PredictionRepository {
  final FirebaseFirestore _db;

  FirestorePredictionRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _votes =>
      _db.collection('predictionVotes');
  CollectionReference<Map<String, dynamic>> get _comments =>
      _db.collection('predictionComments');

  // 전에는 경기마다 투표 전체를 구독해 비율을 셌다. 화면에 뜬 경기 수 ×
  // 투표 수만큼 읽어 사용자가 늘면 비용이 급격히 불었다. 이제 서버가 센 문서
  // 하나와 내 투표 하나만 읽는다(보안 규칙도 투표 목록 읽기를 막는다).
  @override
  Stream<({int home, int away})> watchTally(String gameId) {
    return _db.collection('predictionTallies').doc(gameId).snapshots().map((d) {
      int n(String k) =>
          ((d.data()?[k] as num?)?.toInt() ?? 0).clamp(0, 1 << 30);
      return (home: n('home'), away: n('away'));
    });
  }

  @override
  Stream<PredictionVote?> watchMyVote({
    required String gameId,
    required String uid,
  }) {
    return _votes.doc('${gameId}_$uid').snapshots().map((d) {
      final data = d.data();
      return data == null ? null : PredictionVote.fromMap(data);
    });
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
    return _comments
        .where('gameId', isEqualTo: gameId)
        .limit(commentPageSize)
        .snapshots()
        .map((snap) {
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
  Future<List<LeaderboardEntry>> getLeaderboard() async {
    final doc = await _db.collection('leaderboard').doc('kbl').get();
    final raw = doc.data()?['entries'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => LeaderboardEntry.fromMap(e.cast<String, Object?>()))
        .whereType<LeaderboardEntry>()
        .toList();
  }
}
