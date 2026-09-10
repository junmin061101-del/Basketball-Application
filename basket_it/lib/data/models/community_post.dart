import 'package:flutter/foundation.dart';

/// 커뮤니티 말머리(게시판 분류).
enum PostCategory { free, team, prediction, question }

extension PostCategoryLabel on PostCategory {
  String get label => switch (this) {
    PostCategory.free => '자유',
    PostCategory.team => '응원',
    PostCategory.prediction => '분석',
    PostCategory.question => '질문',
  };

  String get code => name;

  static PostCategory fromCode(Object? code) => switch (code) {
    'team' => PostCategory.team,
    'prediction' => PostCategory.prediction,
    'question' => PostCategory.question,
    _ => PostCategory.free,
  };
}

/// 커뮤니티 게시글.
@immutable
class CommunityPost {
  final String id;
  final String uid;
  final String displayName;
  final PostCategory category;
  final String title;
  final String body;
  final int commentCount;
  final List<String> likedBy;
  final DateTime? createdAt;

  const CommunityPost({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.category,
    required this.title,
    required this.body,
    this.commentCount = 0,
    this.likedBy = const [],
    this.createdAt,
  });

  int get likeCount => likedBy.length;
  bool likedByMe(String? myUid) => myUid != null && likedBy.contains(myUid);

  Map<String, Object?> toMap() => {
    'uid': uid,
    'displayName': displayName,
    'category': category.code,
    'title': title,
    'body': body,
    'commentCount': commentCount,
    'likedBy': likedBy,
  };

  static CommunityPost? fromMap(String id, Map<String, Object?> data) {
    final uid = data['uid'];
    final title = data['title'];
    final body = data['body'];
    if (uid is! String || title is! String || body is! String) return null;
    return CommunityPost(
      id: id,
      uid: uid,
      displayName: (data['displayName'] as String?) ?? '사용자',
      category: PostCategoryLabel.fromCode(data['category']),
      title: title,
      body: body,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      likedBy: ((data['likedBy'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      createdAt: toDateOrNull(data['createdAt']),
    );
  }
}

/// 게시글에 달리는 댓글.
@immutable
class PostComment {
  final String id;
  final String postId;
  final String uid;
  final String displayName;
  final String text;
  final DateTime? createdAt;

  const PostComment({
    required this.id,
    required this.postId,
    required this.uid,
    required this.displayName,
    required this.text,
    this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'postId': postId,
    'uid': uid,
    'displayName': displayName,
    'text': text,
  };

  static PostComment? fromMap(String id, Map<String, Object?> data) {
    final postId = data['postId'];
    final uid = data['uid'];
    final text = data['text'];
    if (postId is! String || uid is! String || text is! String) return null;
    return PostComment(
      id: id,
      postId: postId,
      uid: uid,
      displayName: (data['displayName'] as String?) ?? '사용자',
      text: text,
      createdAt: toDateOrNull(data['createdAt']),
    );
  }
}

/// Firestore Timestamp를 DateTime으로. 타입 의존을 피하려고 dynamic 호출.
DateTime? toDateOrNull(Object? v) {
  if (v == null) return null;
  try {
    // ignore: avoid_dynamic_calls
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
