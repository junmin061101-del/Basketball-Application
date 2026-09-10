import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/moderation.dart';
import '../../providers/moderation_providers.dart';
import '../../providers/prediction_providers.dart';

/// 신고 / 차단 메뉴를 여는 공용 진입점.
///
/// 글·댓글 어디서든 같은 흐름을 쓰도록 한 곳에 모아 둔다.
Future<void> showModerationMenu(
  BuildContext context,
  WidgetRef ref, {
  required String targetId,
  required ReportTargetType targetType,
  required String targetUid,
  required String targetLabel,
}) async {
  final me = ref.read(currentUserProvider);
  if (me == null) return;
  if (me.uid == targetUid) return; // 내 글에는 신고 메뉴를 띄우지 않는다

  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.flag_outlined, color: AppColors.negative),
            title: const Text('신고하기'),
            subtitle: Text('$targetLabel을(를) 운영자에게 신고해요'),
            onTap: () => Navigator.pop(ctx, 'report'),
          ),
          ListTile(
            leading: const Icon(
              Icons.block,
              color: AppColors.textSecondary,
            ),
            title: const Text('이 사용자 차단'),
            subtitle: const Text('이 사용자의 글과 댓글이 더 이상 보이지 않아요'),
            onTap: () => Navigator.pop(ctx, 'block'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  if (action == 'block') {
    await ref.read(blockedUsersProvider.notifier).block(targetUid);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('차단했어요. 이 사용자의 글이 보이지 않아요.'),
          action: SnackBarAction(
            label: '실행 취소',
            onPressed: () =>
                ref.read(blockedUsersProvider.notifier).unblock(targetUid),
          ),
        ),
      );
    return;
  }

  await _showReportDialog(
    context,
    ref,
    targetId: targetId,
    targetType: targetType,
    targetUid: targetUid,
  );
}

Future<void> _showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetId,
  required ReportTargetType targetType,
  required String targetUid,
}) async {
  final me = ref.read(currentUserProvider);
  if (me == null) return;

  final detailController = TextEditingController();
  var reason = ReportReason.abuse;

  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('신고하기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<ReportReason>(
              groupValue: reason,
              onChanged: (v) => setState(() => reason = v ?? reason),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final r in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: r,
                      title: Text(
                        r.label,
                        style: const TextStyle(fontSize: 14),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppColors.primary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: detailController,
              maxLength: 200,
              maxLines: 2,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                hintText: '자세한 내용 (선택)',
                counterText: '',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '신고',
              style: TextStyle(
                color: AppColors.negative,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  final detail = detailController.text.trim();
  detailController.dispose();
  if (submitted != true || !context.mounted) return;

  try {
    await ref
        .read(moderationRepositoryProvider)
        .submitReport(
          Report(
            targetId: targetId,
            targetType: targetType,
            targetUid: targetUid,
            reporterUid: me.uid,
            reason: reason,
            detail: detail,
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('신고를 접수했어요. 운영자가 확인할게요.')),
      );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('신고하지 못했어요: $e')));
  }
}
