import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/game_time.dart';
import '../../../data/models/game.dart';
import '../../../data/models/team.dart';
import '../../../providers/onboarding_providers.dart';
import '../../../shared/widgets/team_logo_placeholder.dart';

/// 경기 카드: 양옆에 팀(로고·이름·전적), 가운데에 점수와 상태.
///
/// 한 줄짜리 낮은 카드로 두어 한 화면에 여러 경기가 들어오게 한다. 이름을
/// 로고 아래에 두므로 "한국가스공사"처럼 긴 이름도 가운데 숫자와 겹치지 않는다.
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surfaceCream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFollowedGame ? AppColors.primary : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: _Side(team: homeTeam, record: homeRecord)),
            SizedBox(
              // 세 자리 점수 둘("103 종료 103")이 줄바꿈 없이 들어가는 너비.
              width: 132,
              child: started
                  ? _Scores(
                      home: game.homeScore,
                      away: game.awayScore,
                      dimLoser: finished,
                      status: finished
                          ? const _StatusLabel.finished()
                          : _StatusLabel.live(game.liveClock),
                    )
                  : Text(
                      timeLabel(game.startTime),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
            ),
            Expanded(child: _Side(team: awayTeam, record: awayRecord)),
          ],
        ),
      ),
    );
  }
}

/// 로고 · 팀 이름 · 전적을 세로로 쌓은 한쪽.
class _Side extends StatelessWidget {
  final Team team;
  final String? record;

  const _Side({required this.team, required this.record});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamLogoPlaceholder(team: team, size: 40),
        const SizedBox(height: 7),
        Text(
          team.name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: AppColors.textPrimary,
          ),
        ),
        if (record != null) ...[
          const SizedBox(height: 3),
          Text(
            record!,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.1,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

/// 점수 사이에 들어가는 작은 상태 글씨("종료" / "LIVE · 3쿼터 07:12").
class _StatusLabel extends StatelessWidget {
  final String? clock;
  final bool isFinished;

  const _StatusLabel.finished() : clock = null, isFinished = true;
  const _StatusLabel.live(this.clock) : isFinished = false;

  @override
  Widget build(BuildContext context) {
    if (isFinished) {
      return const Text(
        '종료',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
          color: AppColors.textTertiary,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'LIVE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1.1,
            color: AppColors.live,
          ),
        ),
        if (clock != null && clock!.isNotEmpty)
          Text(
            clock!,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: AppColors.live,
            ),
          ),
      ],
    );
  }
}

class _Scores extends StatelessWidget {
  final int home;
  final int away;
  final bool dimLoser;
  final Widget status;

  const _Scores({
    required this.home,
    required this.away,
    required this.dimLoser,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color colorFor(int mine, int other) => dimLoser && mine < other
        ? AppColors.textTertiary
        : AppColors.textPrimary;

    const style = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w900,
      height: 1.05,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            '$home',
            textAlign: TextAlign.right,
            maxLines: 1,
            softWrap: false,
            style: style.copyWith(color: colorFor(home, away)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: SizedBox(width: 34, child: status),
        ),
        Expanded(
          child: Text(
            '$away',
            textAlign: TextAlign.left,
            maxLines: 1,
            softWrap: false,
            style: style.copyWith(color: colorFor(away, home)),
          ),
        ),
      ],
    );
  }
}
