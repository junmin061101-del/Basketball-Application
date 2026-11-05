import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/community_post.dart';
import '../data/models/league.dart';
import '../data/repositories/community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return FirestoreCommunityRepository();
});

/// 커뮤니티에서 보고 있는 리그 게시판. 새 글도 이 게시판에 올라간다.
final communityLeagueProvider = StateProvider<League>((ref) => League.kbl);

/// 커뮤니티 목록에서 선택된 말머리. null이면 전체.
final postCategoryFilterProvider = StateProvider<PostCategory?>((ref) => null);

/// 선택된 말머리의 게시글 목록(최신순).
final communityPostsProvider = StreamProvider<List<CommunityPost>>((ref) {
  final category = ref.watch(postCategoryFilterProvider);
  return ref
      .watch(communityRepositoryProvider)
      .watchPosts(
        league: ref.watch(communityLeagueProvider),
        category: category,
      );
});

/// 게시글 하나(좋아요·댓글 수 실시간 반영).
final communityPostProvider = StreamProvider.family<CommunityPost?, String>((
  ref,
  postId,
) {
  return ref.watch(communityRepositoryProvider).watchPost(postId);
});

/// 게시글의 댓글 목록(오래된 순).
final postCommentsProvider = StreamProvider.family<List<PostComment>, String>((
  ref,
  postId,
) {
  return ref.watch(communityRepositoryProvider).watchComments(postId);
});
