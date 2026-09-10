import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/moderation_providers.dart';

/// 차단한 사용자 목록을 확인하고 해제하는 화면.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider).toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('차단한 사용자')),
      body: blocked.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.block,
                      size: 40,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '차단한 사용자가 없어요.\n글이나 댓글을 길게 눌러 차단할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: blocked.length,
              separatorBuilder: (_, _) => const Divider(height: 20),
              itemBuilder: (context, i) {
                final uid = blocked[i];
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.surfaceElevated,
                      child: const Icon(
                        Icons.person_outline,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        // 상대의 이름은 저장하지 않으므로 식별자 앞부분만 보여준다.
                        '사용자 ${uid.substring(0, uid.length < 6 ? uid.length : 6)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(blockedUsersProvider.notifier).unblock(uid),
                      child: const Text('차단 해제'),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
