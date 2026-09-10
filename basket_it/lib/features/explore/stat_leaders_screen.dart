import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/league.dart';
import '../../data/models/player.dart';
import '../../data/models/player_season_stats.dart';
import '../../data/models/team.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/player_avatar.dart';
import '../player/player_detail_screen.dart';
import 'award_race_view.dart';
import 'ranking_categories.dart';

/// 탐색 - 랭킹.
///
/// 선수 기록 순위(네이버 스포츠와 같은 20개 부문)를 보여주고, NBA는 수상
/// 레이스(MVP·올해의 수비수·신인왕)도 함께 둔다.
class StatLeadersScreen extends ConsumerStatefulWidget {
  const StatLeadersScreen({super.key});

  @override
  ConsumerState<StatLeadersScreen> createState() => _StatLeadersScreenState();
}

class _StatLeadersScreenState extends ConsumerState<StatLeadersScreen> {
  bool _showAwards = false;

  @override
  Widget build(BuildContext context) {
    final isNba = ref.watch(selectedLeagueProvider) == League.nba;
    return Scaffold(
      appBar: AppBar(title: const Text('랭킹')),
      body: Column(
        children: [
          if (isNba)
            _ModeSwitch(
              showAwards: _showAwards,
              onChanged: (value) => setState(() => _showAwards = value),
            ),
          Expanded(
            child: isNba && _showAwards
                ? const AwardRaceView()
                : const _RecordRankings(),
          ),
        ],
      ),
    );
  }
}

/// 기록 순위 / 수상 레이스 전환.
class _ModeSwitch extends StatelessWidget {
  final bool showAwards;
  final ValueChanged<bool> onChanged;

  const _ModeSwitch({required this.showAwards, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, bool value) {
      final active = showAwards == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? AppColors.border : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(children: [segment('기록 순위', false), segment('수상 레이스', true)]),
    );
  }
}

class _RecordRankings extends ConsumerWidget {
  const _RecordRankings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(currentSeasonStatsAllProvider);
    final playersAsync = ref.watch(allPlayersProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return teamsAsync.when(
      loading: () => const _Loading(),
      error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
      data: (teams) => playersAsync.when(
        loading: () => const _Loading(),
        error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
        data: (players) => statsAsync.when(
          loading: () => const _Loading(),
          error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
          data: (stats) {
            // 리그가 주지 않는 기록(KBL의 더블더블 등)은 부문째 숨긴다.
            final categories = [
              for (final c in rankingCategories)
                if (isCategoryAvailable(stats, c)) c,
            ];
            if (categories.isEmpty) {
              return Center(
                child: Text(
                  '아직 이번 시즌 기록이 없어요',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            final teamById = {for (final t in teams) t.id: t};
            final playerById = {for (final p in players) p.id: p};
            return DefaultTabController(
              key: ValueKey(categories.length),
              length: categories.length,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [for (final c in categories) Tab(text: c.label)],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final category in categories)
                          _RankingList(
                            category: category,
                            stats: stats,
                            playerById: playerById,
                            teamById: teamById,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  final RankingCategory category;
  final List<PlayerSeasonStats> stats;
  final Map<String, Player> playerById;
  final Map<String, Team> teamById;

  const _RankingList({
    required this.category,
    required this.stats,
    required this.playerById,
    required this.teamById,
  });

  @override
  Widget build(BuildContext context) {
    final rankingContext = RankingContext.of(stats);
    final rows = [
      for (final row in rankPlayers(stats, category))
        if (playerById.containsKey(row.stats.playerId)) row,
    ];
    final season = stats.isEmpty ? '' : stats.first.season;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Text(
          [
            if (season.isNotEmpty) '$season 시즌',
            rankingContext.noteFor(category),
          ].join(' · '),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                '기준을 채운 선수가 아직 없어요',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else ...[
          _TopLeaderCard(
            category: category,
            player: playerById[rows.first.stats.playerId]!,
            team: teamById[rows.first.stats.teamId],
            value: rows.first.value,
          ),
          const SizedBox(height: 16),
          for (var i = 1; i < rows.length; i++) ...[
            if (i > 1) const Divider(),
            _LeaderRow(
              rank: rows[i].rank,
              player: playerById[rows[i].stats.playerId]!,
              team: teamById[rows[i].stats.teamId],
              value: category.format(rows[i].value),
              unit: category.unit,
            ),
          ],
        ],
      ],
    );
  }
}

/// 부문 1위 선수는 카드를 크게 강조해서 보여준다.
class _TopLeaderCard extends StatelessWidget {
  final RankingCategory category;
  final Player player;
  final Team? team;
  final double value;

  const _TopLeaderCard({
    required this.category,
    required this.player,
    required this.team,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final accent = team?.primaryColor ?? AppColors.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: player)),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // 반투명 → 불투명 그라데이션은 중간이 짙게 섞인다(검정 팀은 회색 띠).
            // 바탕에 먼저 섞어 불투명한 색끼리 잇는다.
            colors: [
              Color.alphaBlend(
                accent.withValues(alpha: 0.16),
                AppColors.surface,
              ),
              AppColors.surface,
            ],
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PlayerAvatar(player: player, radius: 30),
                Positioned(
                  left: -4,
                  top: -6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${category.label} 1위',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    player.name,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 22),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    team?.fullName ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  category.format(value),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.unit,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
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

class _LeaderRow extends StatelessWidget {
  final int rank;
  final Player player;
  final Team? team;
  final String value;
  final String unit;

  const _LeaderRow({
    required this.rank,
    required this.player,
    required this.team,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: player)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: rank <= 3
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            PlayerAvatar(player: player, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    team?.fullName ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
