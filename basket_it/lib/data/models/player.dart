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

  /// 화면에 그대로 보여줄 포지션 표기.
  ///
  /// 리그마다 알려주는 정밀도가 다르다. ESPN은 NBA 선수를 가드/포워드/센터
  /// 세 가지로만 주므로, [position] enum을 그대로 쓰면 "가드"를
  /// "포인트가드"라고 적게 된다. 값이 있으면 이쪽을 먼저 쓴다.
  final String? positionLabel;

  const Player({
    required this.id,
    required this.name,
    required this.teamId,
    required this.position,
    required this.backNumber,
    this.followerCount = 0,
    this.positionLabel,
  });

  /// 화면에 보여줄 포지션. 리그가 알려준 표기가 있으면 그걸 쓴다.
  String get positionText => positionLabel ?? position.label;

  @override
  bool operator ==(Object other) => other is Player && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
