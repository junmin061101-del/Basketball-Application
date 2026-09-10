import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/name_mask.dart';
import '../../data/models/community_post.dart';
import '../../data/models/moderation.dart';
import '../../providers/community_providers.dart';
import '../../providers/moderation_providers.dart';
import '../../providers/prediction_providers.dart';
import 'report_sheet.dart';
import 'blocked_users_screen.dart';
import 'post_detail_screen.dart';
import 'write_post_screen.dart';

/// 커뮤니티 탭: 자유롭게 글을 쓰고 댓글로 대화하는 게시판.
class CommunityTab extends ConsumerWidget {
  const CommunityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(postCategoryFilterProvider);
    final postsAsync = ref.watch(communityPostsProvider);
    final me = ref.watch(currentUserProvider);
    final blocked = ref.watch(blockedUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티'),
        actions: [
          IconButton(
            tooltip: '차단한 사용자',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
            ),
            icon: const Icon(
              Icons.block,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: me == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WritePostScreen()),
              ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: const Text('글쓰기'),
      ),
      body: Column(
        children: [
          _CategoryChips(
            selected: filter,
            onSelected: (c) =>
                ref.read(postCategoryFilterProvider.notifier).state = c,
          ),
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
              data: (allPosts) {
                // 차단한 사용자의 글은 목록에서 감춘다.
                final posts = allPosts
                    .where((p) => !blocked.contains(p.uid))
                    .toList();
                if (posts.isEmpty) {
                  return _EmptyState(hasFilter: filter != null);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  itemBuilder: (context, i) =>
                      _PostRow(post: posts[i], myUid: me?.uid),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final PostCategory? selected;
  final ValueChanged<PostCategory?> onSelected;

  const _CategoryChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = <(String, PostCategory?)>[
      ('전체', null),
      for (final c in PostCategory.values) (c.label, c),
    ];
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
        children: [
          for (final (label, category) in items) ...[
            _Chip(
              label: label,
              active: selected == category,
              onTap: () => onSelected(category),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.textPrimary : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PostRow extends ConsumerWidget {
  final CommunityPost post;
  final String? myUid;

  const _PostRow({required this.post, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)),
      ),
      // 남의 글을 길게 누르면 신고/차단 메뉴가 열린다.
      onLongPress: post.uid == myUid
          ? null
          : () => showModerationMenu(
              context,
              ref,
              targetId: post.id,
              targetType: ReportTargetType.post,
              targetUid: post.uid,
              targetLabel: '이 게시글',
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CategoryBadge(category: post.category),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${maskDisplayName(post.displayName)} · ${formatTimeAgo(post.createdAt)}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 16, height: 1.3),
            ),
            if (post.body.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                post.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  post.likedByMe(myUid)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  size: 15,
                  color: post.likedByMe(myUid)
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text('${post.likeCount}', style: _metaStyle),
                const SizedBox(width: 14),
                const Icon(
                  Icons.mode_comment_outlined,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: _metaStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _metaStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );
}

class _CategoryBadge extends StatelessWidget {
  final PostCategory category;

  const _CategoryBadge({required this.category});

  Color get _color => switch (category) {
    PostCategory.free => AppColors.primary,
    PostCategory.team => const Color(0xFF1F7A4D),
    PostCategory.prediction => const Color(0xFF2A3F8F),
    PostCategory.question => const Color(0xFF8E1B3A),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;

  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilter ? '이 말머리에는 아직 글이 없어요' : '아직 글이 없어요.\n첫 글을 남겨보세요!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// 커뮤니티 전반에서 쓰는 상대 시간 표기.
String formatTimeAgo(DateTime? time) {
  if (time == null) return '방금';
  final d = DateTime.now().difference(time);
  if (d.inMinutes < 1) return '방금';
  if (d.inMinutes < 60) return '${d.inMinutes}분 전';
  if (d.inHours < 24) return '${d.inHours}시간 전';
  if (d.inDays < 7) return '${d.inDays}일 전';
  return '${time.month}월 ${time.day}일';
}
