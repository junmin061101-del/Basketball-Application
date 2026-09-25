import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game.dart';
import '../../../data/models/team.dart';
import '../../../providers/onboarding_providers.dart';
import '../../../shared/widgets/team_logo_placeholder.dart';

/// 경기 카드: 크림색 판에 양 팀 이름·전적과 가운데 점수.
///
/// 디자인대로 로고 없이 이름과 숫자만 둔다. 끝난 경기는 이긴 쪽 점수만 진하게
/// 보이고, 예정 경기는 점수 자리에 팁오프 시각이 들어간다.
class GameCard extends ConsumerWidget {
  final Game game;
  final Team homeTeam;
  final Team awayTeam;

  /// "5승 2패". 순위표가 아직 없으면 null.
  final String? homeRecord;
  final String? awayRecord;

  final VoidCallback onTap;

  const GameCard({
    super.key,
    required this.game,
    required this.homeTeam,
    required this.awayTeam,
    required this.onTap,
    this.homeRecord,
    this.awayRecord,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedIds = ref.watch(followedTeamIdsProvider);
    final isFollowedGame =
        followedIds.contains(homeTeam.id) || followedIds.contains(awayTeam.id);
    final finished = game.status == GameStatus.finished;
    final started = game.status != GameStatus.scheduled;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFollowedGame ? AppColors.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (game.status == GameStatus.live) ...[
              _LiveLabel(clock: game.liveClock),
              const SizedBox(height: 8),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _Side(
                    team: homeTeam,
                    record: homeRecord,
                    alignEnd: false,
                  ),
                ),
                if (started)
                  _Scores(
                    home: game.homeScore,
                    away: game.awayScore,
                    dimLoser: finished,
                  )
                else
                  Text(
                    tipOffLabel(game.startTime),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Expanded(
                  child: _Side(
                    team: awayTeam,
                    record: awayRecord,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final Team team;
  final String? record;
  final bool alignEnd;

  const _Side({
    required this.team,
    required this.record,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    final texts = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          team.shortName,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (record != null) ...[
          const SizedBox(height: 3),
          Text(
            record!,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
    final logo = TeamLogoPlaceholder(team: team, size: 34);
    return Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignEnd
          ? [Flexible(child: texts), const SizedBox(width: 10), logo]
          : [logo, const SizedBox(width: 10), Flexible(child: texts)],
    );
  }
}

class _Scores extends StatelessWidget {
  final int home;
  final int away;
  final bool dimLoser;

  const _Scores({
    required this.home,
    required this.away,
    required this.dimLoser,
  });

  @override
  Widget build(BuildContext context) {
    Color colorFor(int mine, int other) => dimLoser && mine < other
        ? AppColors.textTertiary
        : AppColors.textPrimary;

    const style = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w900,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('$home', style: style.copyWith(color: colorFor(home, away))),
          const SizedBox(width: 10),
          Text('$away', style: style.copyWith(color: colorFor(away, home))),
        ],
      ),
    );
  }
}

class _LiveLabel extends StatelessWidget {
  final String? clock;

  const _LiveLabel({required this.clock});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
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
          'LIVE${clock == null || clock!.isEmpty ? '' : ' · $clock'}',
          style: const TextStyle(
            color: AppColors.live,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// 기기 시간 기준 "오전 8:30".
String tipOffLabel(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.hour < 12 ? '오전' : '오후'} $hour:$minute';
}
