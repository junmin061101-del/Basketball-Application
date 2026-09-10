import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/player.dart';
import '../../data/models/player_season_stats.dart';
import '../../data/models/team.dart';
import '../../providers/repository_providers.dart';
import '../player/player_detail_screen.dart';

class _Category {
  final String label;
  final String unit;
  final double Function(PlayerSeasonStats) value;

  const _Category(this.label, this.unit, this.value);
}

const _categories = <_Category>[
  _Category('득점', 'PPG', _points),
  _Category('리바운드', 'RPG', _rebounds),
  _Category('어시스트', 'APG', _assists),
  _Category('스틸', 'SPG', _steals),
  _Category('블록', 'BPG', _blocks),
];

double _points(PlayerSeasonStats s) => s.points;
double _rebounds(PlayerSeasonStats s) => s.reb;
double _assists(PlayerSeasonStats s) => s.ast;
double _steals(PlayerSeasonStats s) => s.stl;
double _blocks(PlayerSeasonStats s) => s.blk;

/// 탐색 - 스탯 리더 화면: 부문별(득점/리바운드/어시스트/스틸/블록) 상위 선수.
class StatLeadersScreen extends ConsumerWidget {
  const StatLeadersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(currentSeasonStatsAllProvider);
    final playersAsync = ref.watch(allPlayersProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('스탯 리더'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final c in _categories) Tab(text: c.label)],
          ),
        ),
        body: teamsAsync.when(
          loading: () => const _Loading(),
          error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
          data: (teams) {
            final teamById = {for (final t in teams) t.id: t};
            return playersAsync.when(
              loading: () => const _Loading(),
              error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
              data: (players) {
                final playerById = {for (final p in players) p.id: p};
                return statsAsync.when(
                  loading: () => const _Loading(),
                  error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
                  data: (stats) => TabBarView(
                    children: [
                      for (final category in _categories)
                        _LeaderList(
                          category: category,
                          stats: stats,
                          playerById: playerById,
                          teamById: teamById,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _LeaderList extends StatelessWidget {
  final _Category category;
  final List<PlayerSeasonStats> stats;
  final Map<String, Player> playerById;
  final Map<String, Team> teamById;

  const _LeaderList({
    required this.category,
    required this.stats,
    required this.playerById,
    required this.teamById,
  });

  @override
  Widget build(BuildContext context) {
    final ranked = [...stats]
      ..sort((a, b) => category.value(b).compareTo(category.value(a)));
    final top = ranked.take(15).toList();
    if (top.isEmpty) return const SizedBox.shrink();

    final leaderPlayer = playerById[top.first.playerId];
    final leaderTeam = teamById[top.first.teamId];
    final rest = top.skip(1).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (leaderPlayer != null)
          _TopLeaderCard(
            category: category,
            player: leaderPlayer,
            team: leaderTeam,
            value: category.value(top.first),
          ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (var i = 0; i < rest.length; i++) ...[
            if (i > 0) const Divider(),
            Builder(
              builder: (context) {
                final stat = rest[i];
                final player = playerById[stat.playerId];
                final team = teamById[stat.teamId];
                if (player == null) return const SizedBox.shrink();
                return _LeaderRow(
                  rank: i + 2,
                  player: player,
                  team: team,
                  value: category.value(stat),
                  unit: category.unit,
                );
              },
            ),
          ],
        ],
      ],
    );
  }
}

/// 부문 1위 선수는 카드를 크게 강조해서 보여준다.
class _TopLeaderCard extends StatelessWidget {
  final _Category category;
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
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerDetailScreen(player: player),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.16), AppColors.surface],
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.surfaceElevated,
                  child: Text(
                    player.name.substring(player.name.length - 1),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Positioned(
                  left: -4,
                  top: -6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      border: Border.all(
                        color: AppColors.surface,
                        width: 2,
                      ),
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
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
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
  final double value;
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
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerDetailScreen(player: player),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 26,
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
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceElevated,
              child: Text(
                player.name.substring(player.name.length - 1),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
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

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
