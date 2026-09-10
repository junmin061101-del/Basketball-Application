import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game.dart';
import '../../../data/models/team.dart';
import '../../../providers/follow_feed_providers.dart';
import '../../../providers/onboarding_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../follow/team_hub_screen.dart';
import '../../games/game_detail_screen.dart';

/// 홈 맨 위에 붙는 "내 팀 오늘 경기" 섹션.
///
/// 팔로우한 팀의 오늘 경기만 보여준다. 진행중 → 예정 → 종료 순으로 놓아
/// 지금 궁금할 만한 것이 위로 온다. 종료된 경기는 그날 안에만 남는다.
/// 오늘 경기가 없으면 섹션 자체가 사라진다.
class FollowedGameSection extends ConsumerWidget {
  const FollowedGameSection({super.key});

  /// 진행중 → 예정 → 종료. 같은 상태끼리는 시작 시각 순.
  static int _priority(GameStatus status) => switch (status) {
    GameStatus.live => 0,
    GameStatus.scheduled => 1,
    GameStatus.finished => 2,
  };

  /// 팔로우한 팀이 오늘 치르는 경기만 골라 우선순위대로 정렬한다.
  static List<Game> pickGames(List<Game> todayGames, Set<String> followedIds) {
    final mine = todayGames
        .where((g) => followedIds.any(g.involvesTeam))
        .toList();
    mine.sort((a, b) {
      final byStatus = _priority(a.status).compareTo(_priority(b.status));
      if (byStatus != 0) return byStatus;
      return a.startTime.compareTo(b.startTime);
    });
    return mine;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed = ref.watch(followedTeamIdsProvider);
    if (followed.isEmpty) return const SizedBox.shrink();

    final todayAsync = ref.watch(todayGamesProvider);
    final games = pickGames(todayAsync.valueOrNull ?? const [], followed);
    if (games.isEmpty) return const SizedBox.shrink();

    final teamById = {
      for (final t in ref.watch(teamsProvider).valueOrNull ?? <Team>[])
        t.id: t,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '내 팀 오늘 경기',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        for (final game in games) ...[
          _GameCard(
            game: game,
            home: teamById[game.homeTeamId],
            away: teamById[game.awayTeamId],
            followed: followed,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _GameCard extends ConsumerWidget {
  final Game game;
  final Team? home;
  final Team? away;
  final Set<String> followed;

  const _GameCard({
    required this.game,
    required this.home,
    required this.away,
    required this.followed,
  });

  bool get _isLive => game.status == GameStatus.live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 팀 정보를 아직 못 불러왔으면 상세로 못 넘어간다(경기 상세가 두 팀을 요구).
    final canOpenDetail = home != null && away != null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: canOpenDetail
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GameDetailScreen(
                  game: game,
                  homeTeam: home!,
                  awayTeam: away!,
                ),
              ),
            )
          : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: _isLive ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isLive ? AppColors.textPrimary : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusLine(game: game, onDark: _isLive),
            const SizedBox(height: 12),
            _ScoreRow(game: game, home: home, away: away, onDark: _isLive),
            if (game.status == GameStatus.scheduled) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _PreGameCompare(game: game, home: home, away: away),
            ],
          ],
        ),
      ),
    );
  }
}

/// 상태 배지 + 시각/진행 상황.
class _StatusLine extends StatelessWidget {
  final Game game;
  final bool onDark;

  const _StatusLine({required this.game, required this.onDark});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (game.status) {
      GameStatus.live => ('LIVE', AppColors.live),
      GameStatus.scheduled => ('경기 예정', AppColors.textSecondary),
      GameStatus.finished => ('경기 종료', AppColors.textSecondary),
    };

    final detail = switch (game.status) {
      GameStatus.live => game.liveClock ?? '진행 중',
      GameStatus.scheduled => _tipOff(game.startTime),
      GameStatus.finished => '최종',
    };

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: game.status == GameStatus.live
                ? AppColors.live
                : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: game.status == GameStatus.live ? Colors.white : color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          detail,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: onDark ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

String _tipOff(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour < 12 ? '오전' : '오후';
  return '$ampm $hour:${t.minute.toString().padLeft(2, '0')} 팁오프';
}

/// 원정 - 점수 - 홈 한 줄.
class _ScoreRow extends StatelessWidget {
  final Game game;
  final Team? home;
  final Team? away;
  final bool onDark;

  const _ScoreRow({
    required this.game,
    required this.home,
    required this.away,
    required this.onDark,
  });

  @override
  Widget build(BuildContext context) {
    final showScore = game.status != GameStatus.scheduled;
    final textColor = onDark ? Colors.white : AppColors.textPrimary;

    return Row(
      children: [
        Expanded(
          child: _TeamSide(
            team: away,
            fallback: game.awayTeamId,
            color: textColor,
          ),
        ),
        if (showScore)
          Text(
            '${game.awayScore}  :  ${game.homeScore}',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: textColor,
            ),
          )
        else
          Text(
            'VS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: onDark ? Colors.white54 : AppColors.textTertiary,
            ),
          ),
        Expanded(
          child: _TeamSide(
            team: home,
            fallback: game.homeTeamId,
            color: textColor,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _TeamSide extends StatelessWidget {
  final Team? team;
  final String fallback;
  final Color color;
  final bool alignEnd;

  const _TeamSide({
    required this.team,
    required this.fallback,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    // NBA는 ESPN 로고를 쓰고, 로고가 없으면 팀 컬러 바탕에 이름 두 글자.
    final crest =
        team?.logoUrl != null ? TeamCrest(team: team!, size: 34) : null;
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        crest ?? Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: (team?.primaryColor ?? AppColors.textTertiary).withValues(
              alpha: 0.16,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            team?.shortName.characters.take(2).toString() ?? '?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: team?.primaryColor ?? AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          team?.shortName ?? fallback,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// 경기 전에만 보여주는 간단한 전력 비교.
///
/// 최근 5경기 성적과 평균 득실점, 그리고 시즌 상대 전적을 나란히 둔다.
class _PreGameCompare extends ConsumerWidget {
  final Game game;
  final Team? home;
  final Team? away;

  const _PreGameCompare({
    required this.game,
    required this.home,
    required this.away,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awayForm = ref.watch(recentFormProvider(game.awayTeamId));
    final homeForm = ref.watch(recentFormProvider(game.homeTeamId));
    final h2h = ref.watch(
      headToHeadProvider((
        teamId: game.homeTeamId,
        opponentId: game.awayTeamId,
      )),
    );

    if (awayForm.valueOrNull == null || homeForm.valueOrNull == null) {
      return const SizedBox(
        height: 54,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    final a = awayForm.value!;
    final h = homeForm.value!;

    return Column(
      children: [
        _CompareRow(label: '최근 5경기', left: a.record, right: h.record),
        const SizedBox(height: 6),
        _CompareRow(
          label: '평균 득점',
          left: a.pointsFor.toStringAsFixed(1),
          right: h.pointsFor.toStringAsFixed(1),
        ),
        const SizedBox(height: 6),
        _CompareRow(
          label: '평균 실점',
          left: a.pointsAgainst.toStringAsFixed(1),
          right: h.pointsAgainst.toStringAsFixed(1),
        ),
        if (h2h.valueOrNull case final games? when games.isNotEmpty) ...[
          const SizedBox(height: 6),
          _CompareRow(
            label: '시즌 상대전적',
            left: '${games.where((g) => teamWon(g, game.awayTeamId)).length}승',
            right: '${games.where((g) => teamWon(g, game.homeTeamId)).length}승',
          ),
        ],
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final String left;
  final String right;

  const _CompareRow({
    required this.label,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            left,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
        Expanded(
          child: Text(
            right,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
