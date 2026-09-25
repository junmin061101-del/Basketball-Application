import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../common/page_header.dart';
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
          PageHeader(
            title: 'Community',
            trailing: IconButton(
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
          ),
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
                  separatorBuilder: (_, _) => const SizedBox.shrink(),
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
          color: active ? AppColors.textPrimary : AppColors.background,
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
            if (post.body.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                post.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _CategoryBadge(category: post.category),
                const SizedBox(width: 10),
                Icon(
                  post.likedByMe(myUid)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  size: 14,
                  color: post.likedByMe(myUid)
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 3),
                Text('${post.likeCount}', style: _metaStyle),
                const SizedBox(width: 10),
                const Icon(
                  Icons.mode_comment_outlined,
                  size: 13,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 3),
                Text('${post.commentCount}', style: _metaStyle),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${formatTimeAgo(post.createdAt)} | '
                    '${maskDisplayName(post.displayName)}',
                    overflow: TextOverflow.ellipsis,
                    style: _metaStyle,
                  ),
                ),
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

  /// 배경과 글자색. 시안에서 뽑은 값이다.
  (Color, Color) get _colors => switch (category) {
    PostCategory.free => (const Color(0xFFF1F5F9), const Color(0xFF475569)),
    PostCategory.team => (const Color(0xFFFFE8D4), const Color(0xFFC2410C)),
    PostCategory.prediction => (
      const Color(0xFFD2DCF7),
      const Color(0xFF1D4ED8),
    ),
    PostCategory.question => (const Color(0xFFFCF6E9), const Color(0xFFB45309)),
  };

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: foreground,
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
