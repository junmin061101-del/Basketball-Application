import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game.dart';
import '../../../data/models/team.dart';
import '../../../providers/onboarding_providers.dart';
import '../../../shared/widgets/team_logo_placeholder.dart';
import '../../explore/team_detail_screen.dart';

/// 경기 카드: 팀 로고 + 팀명 + 스코어, 라이브 표시.
class GameCard extends ConsumerWidget {
  final Game game;
  final Team homeTeam;
  final Team awayTeam;
  final VoidCallback onTap;

  const GameCard({
    super.key,
    required this.game,
    required this.homeTeam,
    required this.awayTeam,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedIds = ref.watch(followedTeamIdsProvider);
    final isFollowedGame =
        followedIds.contains(homeTeam.id) || followedIds.contains(awayTeam.id);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFollowedGame ? AppColors.primary : AppColors.border,
            width: isFollowedGame ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusRow(game: game),
            const SizedBox(height: 12),
            _TeamRow(
              team: homeTeam,
              score: game.homeScore,
              showScore: game.status != GameStatus.scheduled,
              followed: followedIds.contains(homeTeam.id),
            ),
            const SizedBox(height: 10),
            _TeamRow(
              team: awayTeam,
              score: game.awayScore,
              showScore: game.status != GameStatus.scheduled,
              followed: followedIds.contains(awayTeam.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final Game game;

  const _StatusRow({required this.game});

  @override
  Widget build(BuildContext context) {
    switch (game.status) {
      case GameStatus.live:
        return Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.live,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'LIVE · ${game.liveClock ?? ''}',
              style: const TextStyle(
                color: AppColors.live,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        );
      case GameStatus.finished:
        return const Text(
          '경기 종료',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        );
      case GameStatus.scheduled:
        // NBA는 한국 시간으로 새벽·오전에 열려 시각이 없으면 헷갈린다.
        return Text(
          '경기 예정 · ${_tipOffLabel(game.startTime)}',
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        );
    }
  }
}

/// 기기 시간 기준 "오전 8:30".
String _tipOffLabel(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.hour < 12 ? '오전' : '오후'} $hour:$minute';
}

class _TeamRow extends StatelessWidget {
  final Team team;
  final int score;
  final bool showScore;
  final bool followed;

  const _TeamRow({
    required this.team,
    required this.score,
    required this.showScore,
    required this.followed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              TeamLogoPlaceholder(team: team, size: 32),
              const SizedBox(width: 10),
              // 팀 이름을 탭했을 때만 팀 상세로 이동한다(카드의 나머지 부분은
              // 경기 상세로 가는 탭 영역과 겹치지 않도록 이름 텍스트만 반응).
              Flexible(
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamDetailScreen(team: team),
                      ),
                    );
                  },
                  child: Text(
                    team.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              if (followed) ...[
                const SizedBox(width: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showScore)
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}
