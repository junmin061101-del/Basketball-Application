import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 온보딩 중 사용자가 선택한 팔로우 팀 id 집합.
///
/// 지금은 메모리에만 보관되며, Firebase 연동(Step 2) 이후 로그인 시점에
/// Firestore의 사용자 문서로 저장된다.
final followedTeamIdsProvider = StateProvider<Set<String>>((ref) => {});

/// 온보딩 중 사용자가 선택한 팔로우 선수 id 집합.
final followedPlayerIdsProvider = StateProvider<Set<String>>((ref) => {});

/// 선수 팔로우 화면의 검색어.
final playerSearchQueryProvider = StateProvider<String>((ref) => '');
