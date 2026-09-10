import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/name_mask.dart';
import '../../data/models/prediction.dart';
import '../../providers/prediction_providers.dart';

/// 승부예측 랭킹: 가장 많이 맞힌 순, 동률이면 가나다순. 1~3등은 크게.
class LeaderboardView extends ConsumerWidget {
  const LeaderboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(leaderboardProvider);
    final me = ref.watch(currentUserProvider);

    return boardAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '아직 확정된 예측이 없어요.\n경기가 끝나면 맞힌 사람 순으로 랭킹이 생겨요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }
        final top = entries.take(3).toList();
        final rest = entries.skip(3).toList();
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.refresh(leaderboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                '동률이면 가나다순으로 정렬돼요',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < top.length; i++) ...[
                _PodiumCard(
                  rank: i + 1,
                  entry: top[i],
                  isMe: top[i].uid == me?.uid,
                ),
                const SizedBox(height: 10),
              ],
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rest.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _RankRow(
                          rank: i + 4,
                          entry: rest[i],
                          isMe: rest[i].uid == me?.uid,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  const _PodiumCard({
    required this.rank,
    required this.entry,
    required this.isMe,
  });

  Color get _accent => switch (rank) {
    1 => const Color(0xFFD4A017),
    2 => const Color(0xFF8E9AA8),
    3 => const Color(0xFFB87333),
    _ => AppColors.textTertiary,
  };

  @override
  Widget build(BuildContext context) {
    final big = rank == 1;
    return Container(
      padding: EdgeInsets.all(big ? 20 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe ? AppColors.primary : _accent.withValues(alpha: 0.5),
          width: isMe ? 1.6 : 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accent.withValues(alpha: big ? 0.2 : 0.12), AppColors.surface],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: big ? 52 : 44,
            height: big ? 52 : 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _accent),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: big ? 24 : 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank위${isMe ? ' · 나' : ''}',
                  style: TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  maskDisplayName(entry.displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: big ? 24 : 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.settled}경기 중 ${entry.correct}적중 · ${(entry.accuracy * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.correct}',
                style: TextStyle(
                  fontSize: big ? 40 : 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              const Text(
                '적중',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  const _RankRow({required this.rank, required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isMe ? AppColors.primary.withValues(alpha: 0.06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceElevated,
            child: Text(
              maskDisplayName(entry.displayName).substring(0, 1),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${maskDisplayName(entry.displayName)}${isMe ? ' (나)' : ''}',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            '${entry.correct}/${entry.settled}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
