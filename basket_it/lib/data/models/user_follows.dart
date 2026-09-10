import 'package:flutter/foundation.dart';

/// 사용자가 팔로우한 팀/선수 id 집합.
@immutable
class UserFollows {
  final Set<String> teamIds;
  final Set<String> playerIds;

  const UserFollows({
    this.teamIds = const {},
    this.playerIds = const {},
  });
}
