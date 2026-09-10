import 'package:flutter/foundation.dart';

/// 선수 포지션.
enum PlayerPosition { pg, sg, sf, pf, c }

extension PlayerPositionLabel on PlayerPosition {
  String get label => switch (this) {
    PlayerPosition.pg => 'PG',
    PlayerPosition.sg => 'SG',
    PlayerPosition.sf => 'SF',
    PlayerPosition.pf => 'PF',
    PlayerPosition.c => 'C',
  };
}

/// KBL 선수 정보.
///
/// [followerCount]는 Firestore 전체 팔로우 집계를 대신하는 목업 값으로,
/// 선수 팔로우 화면에서 "가장 많이 팔로우된 선수" 정렬 기준으로 사용된다.
@immutable
class Player {
  final String id;
  final String name;
  final String teamId;
  final PlayerPosition position;
  final int backNumber;
  final int followerCount;

  const Player({
    required this.id,
    required this.name,
    required this.teamId,
    required this.position,
    required this.backNumber,
    this.followerCount = 0,
  });

  @override
  bool operator ==(Object other) => other is Player && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
