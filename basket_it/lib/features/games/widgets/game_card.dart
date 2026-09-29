import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/game_time.dart';
import '../../../data/models/game.dart';
import '../../../data/models/team.dart';
import '../../../providers/onboarding_providers.dart';
import '../../../shared/widgets/team_logo_placeholder.dart';

/// 경기 카드: 맨 위에 경기 상태, 가운데에 팁오프 시각(또는 점수),
/// 좌우에 팀 로고·이름·전적을 세로로 쌓는다.
///
/// 이름을 로고 아래에 두면 "한국가스공사"처럼 긴 이름도 가운데 시각과 겹치지
/// 않고, 카드가 커져 한눈에 읽힌다. 끝난 경기는 진 쪽 점수를 흐리게 둔다.
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceCream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFollowedGame ? AppColors.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (game.status == GameStatus.live)
              _LiveLabel(clock: game.liveClock)
            else
              Text(
                finished ? '경기 종료' : dayLabel(game.startTime),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Side(team: homeTeam, record: homeRecord)),
                Padding(
                  // 로고 높이의 가운데에 시각·점수가 오게 맞춘다.
                  padding: const EdgeInsets.only(top: 14),
                  child: started
                      ? _Scores(
                          home: game.homeScore,
                          away: game.awayScore,
                          dimLoser: finished,
                        )
                      : Text(
                          timeLabel(game.startTime),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            height: 1.0,
                          ),
                        ),
                ),
                Expanded(child: _Side(team: awayTeam, record: awayRecord)),
              ],
            ),
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
        TeamLogoPlaceholder(team: team, size: 56),
        const SizedBox(height: 11),
        Text(
          team.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        if (record != null) ...[
          const SizedBox(height: 4),
          Text(
            record!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
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
      fontSize: 30,
      fontWeight: FontWeight.w900,
      height: 1.0,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        Text('$home', style: style.copyWith(color: colorFor(home, away))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 7),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Text('$away', style: style.copyWith(color: colorFor(away, home))),
      ],
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
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
