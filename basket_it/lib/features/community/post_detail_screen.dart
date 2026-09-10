import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/name_mask.dart';
import '../../data/models/community_post.dart';
import '../../data/models/moderation.dart';
import '../../providers/community_providers.dart';
import '../../providers/moderation_providers.dart';
import '../../providers/prediction_providers.dart';
import 'community_tab.dart' show formatTimeAgo;
import 'report_sheet.dart';

/// 게시글 상세: 본문 + 좋아요 + 댓글.
class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final user = ref.read(currentUserProvider);
    if (text.isEmpty || user == null || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .addComment(
            PostComment(
              id: '',
              postId: widget.postId,
              uid: user.uid,
              displayName: maskDisplayName(user.displayName),
              text: text,
            ),
          );
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('글을 삭제할까요?'),
        content: const Text('삭제한 글은 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.negative),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(communityRepositoryProvider).deletePost(widget.postId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(communityPostProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글'),
        actions: [
          if (me != null && postAsync.valueOrNull != null)
            if (postAsync.valueOrNull!.uid == me.uid)
              IconButton(
                onPressed: _deletePost,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textSecondary,
                ),
              )
            else
              IconButton(
                onPressed: () => showModerationMenu(
                  context,
                  ref,
                  targetId: widget.postId,
                  targetType: ReportTargetType.post,
                  targetUid: postAsync.valueOrNull!.uid,
                  targetLabel: '이 게시글',
                ),
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                ),
              ),
        ],
      ),
      body: postAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
        data: (post) {
          if (post != null && ref.watch(blockedUsersProvider).contains(post.uid)) {
            return _BlockedNotice(
              onUnblock: () =>
                  ref.read(blockedUsersProvider.notifier).unblock(post.uid),
            );
          }
          if (post == null) {
            return Center(
              child: Text(
                '삭제된 글이에요',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    Text(
                      post.title,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${post.category.label} · ${maskDisplayName(post.displayName)} · ${formatTimeAgo(post.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    if (post.body.trim().isNotEmpty)
                      Text(
                        post.body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.6,
                          fontSize: 15,
                        ),
                      ),
                    const SizedBox(height: 20),
                    _LikeButton(post: post, myUid: me?.uid),
                    const SizedBox(height: 24),
                    Text(
                      '댓글 ${post.commentCount}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    commentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      error: (err, _) => Text('불러오지 못했어요: $err'),
                      data: (allComments) {
                        final blocked = ref.watch(blockedUsersProvider);
                        final comments = allComments
                            .where((c) => !blocked.contains(c.uid))
                            .toList();
                        if (comments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                '첫 댓글을 남겨보세요',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final c in comments) ...[
                              _CommentTile(
                                comment: c,
                                isMine: c.uid == me?.uid,
                                onDelete: () => ref
                                    .read(communityRepositoryProvider)
                                    .deleteComment(
                                      postId: widget.postId,
                                      commentId: c.id,
                                    ),
                                onReport: c.uid == me?.uid
                                    ? null
                                    : () => showModerationMenu(
                                        context,
                                        ref,
                                        targetId: c.id,
                                        targetType: ReportTargetType.comment,
                                        targetUid: c.uid,
                                        targetLabel: '이 댓글',
                                      ),
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              _CommentInput(
                controller: _controller,
                enabled: me != null && !_sending,
                hint: me == null ? '로그인 후 참여할 수 있어요' : '댓글을 남겨보세요',
                onSend: _send,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LikeButton extends ConsumerWidget {
  final CommunityPost post;
  final String? myUid;

  const _LikeButton({required this.post, required this.myUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = post.likedByMe(myUid);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: myUid == null
            ? null
            : () => ref
                  .read(communityRepositoryProvider)
                  .toggleLike(postId: post.id, uid: myUid!),
        icon: Icon(
          liked ? Icons.favorite : Icons.favorite_border,
          size: 18,
          color: liked ? Colors.white : AppColors.primary,
        ),
        label: Text('좋아요 ${post.likeCount}'),
        style: OutlinedButton.styleFrom(
          backgroundColor: liked ? AppColors.primary : Colors.transparent,
          foregroundColor: liked ? Colors.white : AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostComment comment;
  final bool isMine;
  final VoidCallback onDelete;
  final VoidCallback? onReport;

  const _CommentTile({
    required this.comment,
    required this.isMine,
    required this.onDelete,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMine
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMine
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.surfaceElevated,
                child: Text(
                  maskDisplayName(comment.displayName).substring(0, 1),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                maskDisplayName(comment.displayName),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                formatTimeAgo(comment.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (isMine)
                GestureDetector(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.close,
                      size: 15,
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              else if (onReport != null)
                GestureDetector(
                  onTap: onReport,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(
                      Icons.more_horiz,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final VoidCallback onSend;

  const _CommentInput({
    required this.controller,
    required this.enabled,
    required this.hint,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLength: 500,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  counterText: '',
                  isDense: true,
                  fillColor: AppColors.background,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

/// 차단한 사용자의 글에 들어왔을 때 보여주는 안내.
class _BlockedNotice extends StatelessWidget {
  final VoidCallback onUnblock;

  const _BlockedNotice({required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              '차단한 사용자의 글이에요',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onUnblock, child: const Text('차단 해제')),
          ],
        ),
      ),
    );
  }
}
