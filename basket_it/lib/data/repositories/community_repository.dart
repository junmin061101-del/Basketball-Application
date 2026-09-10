import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/community_post.dart';

/// 커뮤니티(자유게시판) 데이터 접근을 추상화한 Repository.
abstract class CommunityRepository {
  /// 최신순 게시글 목록. [category]가 null이면 전체.
  Stream<List<CommunityPost>> watchPosts({PostCategory? category});

  /// 게시글 하나를 실시간으로 구독한다(좋아요·댓글 수 반영).
  Stream<CommunityPost?> watchPost(String postId);

  Future<String> createPost(CommunityPost post);
  Future<void> deletePost(String postId);

  /// 좋아요 토글. 이미 눌렀으면 취소한다.
  Future<void> toggleLike({required String postId, required String uid});

  Stream<List<PostComment>> watchComments(String postId);
  Future<void> addComment(PostComment comment);
  Future<void> deleteComment({required String postId, required String commentId});
}

class FirestoreCommunityRepository implements CommunityRepository {
  final FirebaseFirestore _db;

  FirestoreCommunityRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('communityPosts');
  CollectionReference<Map<String, dynamic>> get _comments =>
      _db.collection('communityComments');

  @override
  Stream<List<CommunityPost>> watchPosts({PostCategory? category}) {
    Query<Map<String, dynamic>> query = _posts;
    if (category != null) {
      query = query.where('category', isEqualTo: category.code);
    }
    // category + createdAt 복합 인덱스를 요구하지 않도록 정렬은 클라이언트에서.
    return query.snapshots().map((snap) {
      final posts = snap.docs
          .map((d) => CommunityPost.fromMap(d.id, d.data()))
          .whereType<CommunityPost>()
          .toList();
      posts.sort(_newestFirst);
      return posts;
    });
  }

  @override
  Stream<CommunityPost?> watchPost(String postId) {
    return _posts.doc(postId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return CommunityPost.fromMap(doc.id, data);
    });
  }

  @override
  Future<String> createPost(CommunityPost post) async {
    final doc = await _posts.add({
      ...post.toMap(),
      'commentCount': 0,
      'likedBy': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  @override
  Future<void> deletePost(String postId) => _posts.doc(postId).delete();

  @override
  Future<void> toggleLike({required String postId, required String uid}) {
    return _db.runTransaction((tx) async {
      final ref = _posts.doc(postId);
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) return;
      final liked = ((data['likedBy'] as List?) ?? const [])
          .whereType<String>()
          .toList();
      tx.update(ref, {
        'likedBy': liked.contains(uid)
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      });
    });
  }

  @override
  Stream<List<PostComment>> watchComments(String postId) {
    return _comments.where('postId', isEqualTo: postId).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => PostComment.fromMap(d.id, d.data()))
          .whereType<PostComment>()
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
  Future<void> addComment(PostComment comment) async {
    await _comments.add({
      ...comment.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    // 목록에서 댓글 수를 보여주기 위해 게시글에 카운터를 올린다.
    await _posts.doc(comment.postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _comments.doc(commentId).delete();
    await _posts.doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  int _newestFirst(CommunityPost a, CommunityPost b) {
    final ta = a.createdAt;
    final tb = b.createdAt;
    if (ta == null && tb == null) return 0;
    if (ta == null) return -1; // 방금 쓴 글은 맨 앞
    if (tb == null) return 1;
    return tb.compareTo(ta);
  }
}
