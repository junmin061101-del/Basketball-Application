import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/name_mask.dart';
import '../../data/models/game.dart';
import '../../data/models/moderation.dart';
import '../../data/models/prediction.dart';
import '../../data/models/team.dart';
import '../../providers/moderation_providers.dart';
import '../../providers/prediction_providers.dart';
import '../community/report_sheet.dart';
import 'prediction_game_card.dart';

/// 경기별 승부예측 상세: 투표 카드 + 실시간 토론.
class PredictionDetailScreen extends ConsumerStatefulWidget {
  final Game game;
  final Team? homeTeam;
  final Team? awayTeam;

  const PredictionDetailScreen({
    super.key,
    required this.game,
    required this.homeTeam,
    required this.awayTeam,
  });

  @override
  ConsumerState<PredictionDetailScreen> createState() =>
      _PredictionDetailScreenState();
}

class _PredictionDetailScreenState
    extends ConsumerState<PredictionDetailScreen> {
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
          .read(predictionRepositoryProvider)
          .addComment(
            PredictionComment(
              id: '',
              gameId: widget.game.id,
              uid: user.uid,
              // 공용 컬렉션에 원본 이름이 남지 않도록 저장 시점에 마스킹한다.
              displayName: maskDisplayName(user.displayName),
              text: text,
            ),
          );
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(gameCommentsProvider(widget.game.id));
    final user = ref.watch(currentUserProvider);
    final title =
        '${widget.homeTeam?.name ?? widget.game.homeTeamId} vs ${widget.awayTeam?.name ?? widget.game.awayTeamId}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              children: [
                PredictionGameCard(
                  game: widget.game,
                  homeTeam: widget.homeTeam,
                  awayTeam: widget.awayTeam,
                  showDiscussButton: false,
                ),
                const SizedBox(height: 24),
                Text('토론', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '경기 시작 1시간 전까지 의견을 나누고 예측을 바꿀 수 있어요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                commentsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  error: (err, _) => Text('불러오지 못했어요: $err'),
                  data: (allComments) {
                    // 차단한 사용자의 댓글은 숨긴다.
                    final blocked = ref.watch(blockedUsersProvider);
                    final comments = allComments
                        .where((c) => !blocked.contains(c.uid))
                        .toList();
                    if (comments.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        alignment: Alignment.center,
                        child: Text(
                          '첫 번째 의견을 남겨보세요',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final c in comments) ...[
                          _CommentTile(
                            comment: c,
                            isMine: c.uid == user?.uid,
                            onReport: c.uid == user?.uid
                                ? null
                                : () => showModerationMenu(
                                    context,
                                    ref,
                                    targetId: c.id,
                                    targetType:
                                        ReportTargetType.predictionComment,
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
          SafeArea(
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
                      controller: _controller,
                      maxLength: 300,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: user == null
                            ? '로그인 후 참여할 수 있어요'
                            : '${maskDisplayName(user.displayName)}(으)로 의견 남기기',
                        counterText: '',
                        isDense: true,
                        fillColor: AppColors.background,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending || user == null ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PredictionComment comment;
  final bool isMine;
  final VoidCallback? onReport;

  const _CommentTile({
    required this.comment,
    required this.isMine,
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
                _timeAgo(comment.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (onReport != null)
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

  String _timeAgo(DateTime? t) {
    if (t == null) return '보내는 중';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '방금';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    return '${d.inDays}일 전';
  }
}
