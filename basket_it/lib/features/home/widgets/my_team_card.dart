import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game.dart';
import '../../../data/models/player_game_stats.dart';
import '../../../data/models/team.dart';
import '../../../providers/game_providers.dart';
import '../../../providers/my_team_providers.dart';
import '../../../providers/onboarding_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../explore/team_list_screen.dart';
import '../../follow/team_hub_screen.dart';
import '../../games/game_detail_screen.dart';
import '../my_team_summary.dart';

/// 홈 맨 위 "내 팀" 영역.
///
/// 지금 리그에서 팔로우한 팀의 순위·연승/연패·앞뒤 팀과의 게임차·최근 5경기와
/// 오늘(없으면 최근) 경기를 뉴스보다 먼저 보여준다. 팔로우한 팀이 여럿이면
/// 위에서 고르고, 없으면 팀을 고르라는 카드를 띄운다.
class MyTeamSection extends ConsumerWidget {
  const MyTeamSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followed = ref.watch(followedTeamIdsProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final teams = (teamsAsync.valueOrNull ?? const <Team>[])
        .where((t) => followed.contains(t.id))
        .toList();

    if (teamsAsync.isLoading && teams.isEmpty) return const _CardLoading();
    if (teams.isEmpty) return const _PickMyTeamCard();

    final selectedId = ref.watch(selectedMyTeamIdProvider);
    final team = teams.firstWhere(
      (t) => t.id == selectedId,
      orElse: () => teams.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (teams.length > 1) ...[
          _TeamSelector(teams: teams, selected: team),
          const SizedBox(height: 10),
        ],
        MyTeamCard(team: team),
      ],
    );
  }
}

class _TeamSelector extends ConsumerWidget {
  final List<Team> teams;
  final Team selected;

  const _TeamSelector({required this.teams, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: teams.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final team = teams[index];
          final active = team.id == selected.id;
          return GestureDetector(
            onTap: () =>
                ref.read(selectedMyTeamIdProvider.notifier).state = team.id,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? AppColors.textPrimary : AppColors.border,
                  width: active ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TeamCrest(team: team, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    team.shortName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 팀 하나의 카드.
class MyTeamCard extends ConsumerWidget {
  final Team team;

  const MyTeamCard({super.key, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(myTeamSummaryProvider(team.id));
    final season = ref.watch(standingsSeasonProvider).valueOrNull;
    final teamById = {
      for (final t in ref.watch(teamsProvider).valueOrNull ?? const <Team>[])
        t.id: t,
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(team: team),
          const SizedBox(height: 14),
          summaryAsync.when(
            loading: () => const SizedBox(
              height: 160,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    '내 팀 정보를 불러오지 못했어요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(myTeamSummaryProvider(team.id)),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
            data: (summary) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RankRow(
                  summary: summary,
                  teamById: teamById,
                  seasonCaption: season?.caption,
                ),
                if (summary.featuredGame != null) ...[
                  const SizedBox(height: 16),
                  _FeaturedGame(
                    team: team,
                    game: summary.featuredGame!,
                    isToday: summary.featuredIsToday,
                    teamById: teamById,
                  ),
                ],
                if (summary.nextGame != null) ...[
                  const SizedBox(height: 12),
                  _NextGameLine(
                    team: team,
                    game: summary.nextGame!,
                    teamById: teamById,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Team team;

  const _Header({required this.team});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => TeamHubScreen(team: team))),
      child: Row(
        children: [
          TeamCrest(team: team, size: 40),
          const SizedBox(width: 10),
          // 이름이 길어도(애틀랜타 호크스) 배지 자리만 남기고 끝까지 쓴다.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    team.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: team.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '내 팀',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: team.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final MyTeamSummary summary;
  final Map<String, Team> teamById;
  final String? seasonCaption;

  const _RankRow({
    required this.summary,
    required this.teamById,
    required this.seasonCaption,
  });

  @override
  Widget build(BuildContext context) {
    final rank = summary.rankLabel;
    final streak = summary.streakLabel;
    final caption = [
      ?seasonCaption,
      if (summary.rank != null) '${summary.wins}승 ${summary.losses}패',
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rank == null)
                Text(
                  '순위 정보가 아직 없어요',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      rank,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (streak != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        streak,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: summary.streak > 0
                              ? AppColors.positive
                              : AppColors.negative,
                        ),
                      ),
                    ],
                  ],
                ),
              if (summary.above != null)
                _NeighborLine(neighbor: summary.above!, teamById: teamById),
              if (summary.below != null)
                _NeighborLine(neighbor: summary.below!, teamById: teamById),
              if (caption.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (summary.lastFive.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '최근 5경기',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final won in summary.lastFive)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _ResultPill(won: won),
                    ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class _NeighborLine extends StatelessWidget {
  final RankNeighbor neighbor;
  final Map<String, Team> teamById;

  const _NeighborLine({required this.neighbor, required this.teamById});

  @override
  Widget build(BuildContext context) {
    final name = teamById[neighbor.teamId]?.shortName ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          children: [
            TextSpan(text: '${neighbor.rank}위 ${withWaGwa(name)} '),
            TextSpan(
              text: gamesBehindLabel(neighbor.gamesBehind),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  final bool won;

  const _ResultPill({required this.won});

  @override
  Widget build(BuildContext context) {
    final color = won ? AppColors.positive : AppColors.negative;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        won ? '승' : '패',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// 오늘(없으면 최근) 경기 박스.
class _FeaturedGame extends ConsumerWidget {
  final Team team;
  final Game game;
  final bool isToday;
  final Map<String, Team> teamById;

  const _FeaturedGame({
    required this.team,
    required this.game,
    required this.isToday,
    required this.teamById,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = teamById[game.homeTeamId];
    final away = teamById[game.awayTeamId];
    if (home == null || away == null) return const SizedBox.shrink();

    final started = game.status != GameStatus.scheduled;
    final title = isToday ? '오늘 경기' : '최근 경기 · ${dayLabel(game.startTime)}';
    final boxScore = started
        ? ref.watch(boxScoreProvider(game)).valueOrNull ?? const []
        : const <PlayerGameStats>[];
    final players = {
      for (final p in ref.watch(allPlayersProvider).valueOrNull ?? const [])
        p.id: p.name,
    };
    final topHome = _topScorer(boxScore, home.id);
    final topAway = _topScorer(boxScore, away.id);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              GameDetailScreen(game: game, homeTeam: home, awayTeam: away),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Side(team: home)),
                Column(
                  children: [
                    if (started)
                      Text(
                        '${game.homeScore} : ${game.awayScore}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      )
                    else
                      Text(
                        timeLabel(game.startTime),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    const SizedBox(height: 4),
                    _StatusChip(game: game),
                  ],
                ),
                Expanded(child: _Side(team: away)),
              ],
            ),
            if (topHome != null || topAway != null) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: team.primaryColor.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 10),
              Text(
                [
                  '최다 득점',
                  if (topHome != null)
                    '${players[topHome.playerId] ?? home.shortName} ${topHome.points}점',
                  if (topAway != null)
                    '${players[topAway.playerId] ?? away.shortName} ${topAway.points}점',
                ].join(' · '),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static PlayerGameStats? _topScorer(
    List<PlayerGameStats> lines,
    String teamId,
  ) {
    PlayerGameStats? best;
    for (final line in lines) {
      if (line.teamId != teamId) continue;
      if (best == null || line.points > best.points) best = line;
    }
    return best;
  }
}

class _Side extends StatelessWidget {
  final Team team;

  const _Side({required this.team});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TeamCrest(team: team, size: 44),
        const SizedBox(height: 6),
        Text(
          team.shortName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Game game;

  const _StatusChip({required this.game});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (game.status) {
      GameStatus.live => (game.liveClock ?? 'LIVE', AppColors.live),
      GameStatus.scheduled => ('경기 예정', AppColors.textSecondary),
      GameStatus.finished => ('경기 종료', AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _NextGameLine extends StatelessWidget {
  final Team team;
  final Game game;
  final Map<String, Team> teamById;

  const _NextGameLine({
    required this.team,
    required this.game,
    required this.teamById,
  });

  @override
  Widget build(BuildContext context) {
    final isHome = game.homeTeamId == team.id;
    final opponent = teamById[isHome ? game.awayTeamId : game.homeTeamId];
    return Row(
      children: [
        const Icon(Icons.event, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '다음 경기 · ${dayLabel(game.startTime)} ${timeLabel(game.startTime)}'
            '${opponent == null ? '' : ' · ${isHome ? 'vs' : '@'} ${opponent.shortName}'}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// 팔로우한 팀이 없을 때.
class _PickMyTeamCard extends StatelessWidget {
  const _PickMyTeamCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.shield_outlined, size: 36, color: AppColors.primary),
          const SizedBox(height: 10),
          const Text(
            '내 팀을 정해 보세요',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            '팔로우한 팀의 순위와 최근 경기를 홈에서 바로 볼 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TeamListScreen())),
            child: const Text('팀 고르기'),
          ),
        ],
      ),
    );
  }
}

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// "4월 8일 (수)". 올해가 아니면 연도를 붙인다.
String dayLabel(DateTime time, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = '${time.month}월 ${time.day}일 (${_weekdays[time.weekday - 1]})';
  return time.year == today.year ? day : '${time.year}년 $day';
}

/// 기기 시간 기준 "오후 7:00".
String timeLabel(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${time.hour < 12 ? '오전' : '오후'} $hour:$minute';
}
