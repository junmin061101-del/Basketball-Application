import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/name_mask.dart';
import '../../data/models/game.dart';
import '../../data/models/prediction.dart';
import '../../data/models/team.dart';
import '../../providers/prediction_providers.dart';
import '../../shared/widgets/team_logo_placeholder.dart';
import 'prediction_detail_screen.dart';

/// 경기 하나의 승부예측 카드: 팀 선택 버튼 + 실시간 비율 + 마감 상태 + 토론 진입.
class PredictionGameCard extends ConsumerWidget {
  final Game game;
  final Team? homeTeam;
  final Team? awayTeam;

  /// 토론 화면 안에서 쓸 때는 "토론" 버튼을 숨긴다.
  final bool showDiscussButton;

  const PredictionGameCard({
    super.key,
    required this.game,
    required this.homeTeam,
    required this.awayTeam,
    this.showDiscussButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final votesAsync = ref.watch(gameVotesProvider(game.id));
    final now = ref.watch(minuteTickProvider).valueOrNull ?? DateTime.now();
    final user = ref.watch(currentUserProvider);
    final votes = votesAsync.valueOrNull ?? const <PredictionVote>[];
    final homeCount = votes.where((v) => v.pick == TeamSide.home).length;
    final awayCount = votes.length - homeCount;
    final myVote = user == null
        ? null
        : votes.where((v) => v.uid == user.uid).firstOrNull;
    final open = game.isPredictionOpen(now);
    final winner = _winner(game);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: myVote != null ? AppColors.primary : AppColors.border,
          width: myVote != null ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _StatusLine(game: game, now: now, open: open)),
              Text(
                _timeLabel(game.startTime),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SideButton(
                  team: homeTeam,
                  fallback: game.homeTeamId,
                  label: '홈',
                  selected: myVote?.pick == TeamSide.home,
                  enabled: open && user != null,
                  isWinner: winner == TeamSide.home,
                  onTap: () => _vote(ref, user, TeamSide.home),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: _SideButton(
                  team: awayTeam,
                  fallback: game.awayTeamId,
                  label: '원정',
                  selected: myVote?.pick == TeamSide.away,
                  enabled: open && user != null,
                  isWinner: winner == TeamSide.away,
                  onTap: () => _vote(ref, user, TeamSide.away),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _RatioBar(
            homeCount: homeCount,
            awayCount: awayCount,
            homeColor: homeTeam?.primaryColor ?? AppColors.primary,
            awayColor: awayTeam?.primaryColor ?? AppColors.textTertiary,
          ),
          if (myVote != null || winner != null) ...[
            const SizedBox(height: 10),
            _ResultLine(myVote: myVote, winner: winner, game: game),
          ],
          if (showDiscussButton) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PredictionDetailScreen(
                        game: game,
                        homeTeam: homeTeam,
                        awayTeam: awayTeam,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: Text('토론 · 참여 ${votes.length}명'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _vote(WidgetRef ref, dynamic user, TeamSide side) async {
    if (user == null) return;
    if (!game.isPredictionOpen()) return;
    await ref
        .read(predictionRepositoryProvider)
        .submitVote(
          PredictionVote(
            gameId: game.id,
            uid: user.uid as String,
            // 공용 컬렉션에 원본 이름이 남지 않도록 저장 시점에 마스킹한다.
            displayName: maskDisplayName(user.displayName as String),
            pick: side,
            gameDate: game.date,
          ),
        );
  }

  TeamSide? _winner(Game game) {
    if (game.status != GameStatus.finished) return null;
    if (game.homeScore == game.awayScore) return null;
    return game.homeScore > game.awayScore ? TeamSide.home : TeamSide.away;
  }

  String _timeLabel(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} 시작';
}

class _StatusLine extends StatelessWidget {
  final Game game;
  final DateTime now;
  final bool open;

  const _StatusLine({required this.game, required this.now, required this.open});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (game.status) {
      GameStatus.live => ('진행 중 · 예측 마감', AppColors.live),
      GameStatus.finished => ('경기 종료 · 결과 확정', AppColors.textTertiary),
      GameStatus.scheduled =>
        open
            ? ('마감까지 ${_remaining(game.predictionDeadline, now)}', AppColors.positive)
            : ('예측 마감', AppColors.textTertiary),
    };
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  String _remaining(DateTime deadline, DateTime now) {
    final d = deadline.difference(now);
    if (d.inDays >= 1) return '${d.inDays}일 ${d.inHours % 24}시간';
    if (d.inHours >= 1) return '${d.inHours}시간 ${d.inMinutes % 60}분';
    return '${d.inMinutes}분';
  }
}

class _SideButton extends StatelessWidget {
  final Team? team;
  final String fallback;
  final String label;
  final bool selected;
  final bool enabled;
  final bool isWinner;
  final VoidCallback onTap;

  const _SideButton({
    required this.team,
    required this.fallback,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.isWinner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = team?.primaryColor ?? AppColors.primary;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            if (team != null)
              TeamLogoPlaceholder(team: team!, size: 40, selected: selected)
            else
              const SizedBox(height: 40),
            const SizedBox(height: 8),
            Text(
              team?.fullName ?? fallback.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 13,
                color: enabled || selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isWinner ? '$label · 승' : label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isWinner ? AppColors.positive : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatioBar extends StatelessWidget {
  final int homeCount;
  final int awayCount;
  final Color homeColor;
  final Color awayColor;

  const _RatioBar({
    required this.homeCount,
    required this.awayCount,
    required this.homeColor,
    required this.awayColor,
  });

  @override
  Widget build(BuildContext context) {
    final total = homeCount + awayCount;
    final homePct = total == 0 ? 50 : (homeCount * 100 / total).round();
    final awayPct = total == 0 ? 50 : 100 - homePct;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$homePct%',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              total == 0 ? '아직 예측이 없어요' : '$total명 참여',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '$awayPct%',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Row(
            children: [
              Expanded(
                flex: (homePct * 10).clamp(1, 999),
                child: Container(
                  height: 8,
                  color: total == 0 ? AppColors.surfaceElevated : homeColor,
                ),
              ),
              Expanded(
                flex: (awayPct * 10).clamp(1, 999),
                child: Container(
                  height: 8,
                  color: total == 0 ? AppColors.surfaceElevated : awayColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultLine extends StatelessWidget {
  final PredictionVote? myVote;
  final TeamSide? winner;
  final Game game;

  const _ResultLine({
    required this.myVote,
    required this.winner,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    if (myVote == null) {
      return Text(
        '결과: ${winner == TeamSide.home ? '홈 승' : '원정 승'} (${game.homeScore}:${game.awayScore})',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final pickLabel = myVote!.pick == TeamSide.home ? '홈' : '원정';
    if (winner == null) {
      return Text(
        '내 예측: $pickLabel 승',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      );
    }
    final hit = winner == myVote!.pick;
    return Row(
      children: [
        Icon(
          hit ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: hit ? AppColors.positive : AppColors.negative,
        ),
        const SizedBox(width: 6),
        Text(
          hit ? '적중! $pickLabel 승 예측 성공' : '아쉽… $pickLabel 승 예측 실패',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: hit ? AppColors.positive : AppColors.negative,
          ),
        ),
      ],
    );
  }
}
