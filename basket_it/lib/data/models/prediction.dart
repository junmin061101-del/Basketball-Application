import 'package:flutter/foundation.dart';

/// 승부예측에서 고른 쪽.
enum TeamSide { home, away }

extension TeamSideCodec on TeamSide {
  String get code => this == TeamSide.home ? 'home' : 'away';

  static TeamSide? fromCode(Object? code) => switch (code) {
    'home' => TeamSide.home,
    'away' => TeamSide.away,
    _ => null,
  };
}

/// 한 사용자의 한 경기 승부예측 투표. Firestore 문서 id는 "{gameId}_{uid}".
@immutable
class PredictionVote {
  final String gameId;
  final String uid;
  final String displayName;
  final TeamSide pick;
  final DateTime gameDate;
  final DateTime? createdAt;

  const PredictionVote({
    required this.gameId,
    required this.uid,
    required this.displayName,
    required this.pick,
    required this.gameDate,
    this.createdAt,
  });

  String get docId => '${gameId}_$uid';

  Map<String, Object?> toMap() => {
    'gameId': gameId,
    'uid': uid,
    'displayName': displayName,
    'pick': pick.code,
    'gameDate': _dateKey(gameDate),
  };

  static PredictionVote? fromMap(Map<String, Object?> data) {
    final pick = TeamSideCodec.fromCode(data['pick']);
    final gameId = data['gameId'];
    final uid = data['uid'];
    final dateStr = data['gameDate'];
    if (pick == null || gameId is! String || uid is! String || dateStr is! String) {
      return null;
    }
    return PredictionVote(
      gameId: gameId,
      uid: uid,
      displayName: (data['displayName'] as String?) ?? '사용자',
      pick: pick,
      gameDate: DateTime.tryParse(dateStr) ?? DateTime.now(),
      createdAt: _toDate(data['createdAt']),
    );
  }
}

/// 승부예측 토론 댓글.
@immutable
class PredictionComment {
  final String id;
  final String gameId;
  final String uid;
  final String displayName;
  final String text;
  final DateTime? createdAt;

  const PredictionComment({
    required this.id,
    required this.gameId,
    required this.uid,
    required this.displayName,
    required this.text,
    this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'gameId': gameId,
    'uid': uid,
    'displayName': displayName,
    'text': text,
  };

  static PredictionComment? fromMap(String id, Map<String, Object?> data) {
    final gameId = data['gameId'];
    final uid = data['uid'];
    final text = data['text'];
    if (gameId is! String || uid is! String || text is! String) return null;
    return PredictionComment(
      id: id,
      gameId: gameId,
      uid: uid,
      displayName: (data['displayName'] as String?) ?? '사용자',
      text: text,
      createdAt: _toDate(data['createdAt']),
    );
  }
}

/// 승부예측 랭킹 한 줄.
@immutable
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int correct;
  final int settled; // 결과가 확정된 예측 수

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.correct,
    required this.settled,
  });

  double get accuracy => settled == 0 ? 0 : correct / settled;
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _toDate(Object? v) {
  if (v == null) return null;
  // cloud_firestore의 Timestamp는 toDate()를 가진다. 타입 의존을 피하려고 dynamic 호출.
  try {
    // ignore: avoid_dynamic_calls
    return (v as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
