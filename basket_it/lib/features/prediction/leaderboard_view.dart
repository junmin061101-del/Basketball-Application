import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/prediction.dart';
import '../../providers/prediction_providers.dart';

/// 승부예측 랭킹: 가장 많이 맞힌 순, 동률이면 가나다순.
///
/// 맨 위에 내 순위 카드를 두고, 1~3등은 큰 줄로, 그 아래는 간단한 줄로 보여준다.
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
        final myIndex = entries.indexWhere((e) => e.uid == me?.uid);
        final top = entries.take(3).toList();
        final rest = entries.skip(3).toList();

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.refresh(leaderboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (myIndex >= 0) ...[
                _MyRankCard(rank: myIndex + 1, entry: entries[myIndex]),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  const Text(
                    '•  ',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                  Text(
                    '동률 시 가나다순 정렬',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < top.length; i++)
                _TopRow(
                  rank: i + 1,
                  entry: top[i],
                  isMe: top[i].uid == me?.uid,
                ),
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(height: 6, color: AppColors.surfaceElevated),
                for (var i = 0; i < rest.length; i++)
                  _RankRow(
                    rank: i + 4,
                    entry: rest[i],
                    isMe: rest[i].uid == me?.uid,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// 이름 첫 글자를 넣은 동그란 자리. 프로필 사진이 없으므로 이걸로 대신한다.
class _Avatar extends StatelessWidget {
  final String name;
  final double size;

  const _Avatar({required this.name, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.border,
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// 맨 위 내 순위 카드.
class _MyRankCard extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;

  const _MyRankCard({required this.rank, required this.entry});

  @override
  Widget build(BuildContext context) {
    final name = entry.displayName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '내 순위',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '현재 순위 $rank위, ${entry.settled}경기 중 ${entry.correct}적중',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(entry.accuracy * 100).round()}%',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              Text(
                '적중률',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 1~3등 줄. 순위 숫자를 빨갛게 크게 적는다.
class _TopRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  const _TopRow({required this.rank, required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final name = entry.displayName;
    return Container(
      color: isMe ? AppColors.primary.withValues(alpha: 0.05) : null,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.negative,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Avatar(name: name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name${isMe ? ' (나)' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.settled}경기 중 ${entry.correct}적중 · '
                  '${(entry.accuracy * 100).round()}%',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            '${entry.correct}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 4등부터. 적중 수와 확정 경기 수만 간단히.
class _RankRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  const _RankRow({required this.rank, required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final name = entry.displayName;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withValues(alpha: 0.05) : null,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _Avatar(name: name, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name${isMe ? ' (나)' : ''}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${entry.correct}/${entry.settled}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
