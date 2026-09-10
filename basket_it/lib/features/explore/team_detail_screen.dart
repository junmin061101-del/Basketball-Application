import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/player.dart';
import '../../data/models/team.dart';
import '../../data/models/team_standing.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/team_logo_placeholder.dart';
import '../player/player_detail_screen.dart';

/// 탐색 - 팀 상세 화면: 팀 성적 + 로스터.
class TeamDetailScreen extends ConsumerWidget {
  final Team team;

  const TeamDetailScreen({super.key, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsProvider);
    final rosterAsync = ref.watch(teamRosterProvider(team.id));

    return Scaffold(
      appBar: AppBar(title: Text(team.fullName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              TeamLogoPlaceholder(team: team, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.fullName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    standingsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (standings) {
                        final matches = standings.where(
                          (s) => s.teamId == team.id,
                        );
                        if (matches.isEmpty) return const SizedBox.shrink();
                        final rank = standings.indexOf(matches.first) + 1;
                        return Text(
                          '$rank위 · ${matches.first.wins}승 ${matches.first.losses}패',
                          style: Theme.of(context).textTheme.bodyMedium,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          standingsAsync.when(
            loading: () => const _Loading(),
            error: (err, _) => Text('불러오지 못했어요: $err'),
            data: (standings) {
              final matches = standings.where((s) => s.teamId == team.id);
              if (matches.isEmpty) return const SizedBox.shrink();
              return _TeamStatCard(standing: matches.first);
            },
          ),
          const SizedBox(height: 28),
          Text('로스터', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          rosterAsync.when(
            loading: () => const _Loading(),
            error: (err, _) => Text('불러오지 못했어요: $err'),
            data: (roster) => _RosterList(roster: roster),
          ),
        ],
      ),
    );
  }
}

class _TeamStatCard extends StatelessWidget {
  final TeamStanding standing;

  const _TeamStatCard({required this.standing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _Stat(label: '승', value: '${standing.wins}'),
          _Stat(label: '패', value: '${standing.losses}'),
          _Stat(label: '승률', value: standing.winPct.toStringAsFixed(3)),
          _Stat(
            label: 'GB',
            value: standing.gamesBehind == 0
                ? '-'
                : standing.gamesBehind.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterList extends StatelessWidget {
  final List<Player> roster;

  const _RosterList({required this.roster});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < roster.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _RosterRow(player: roster[i]),
          ],
        ],
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  final Player player;

  const _RosterRow({required this.player});

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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '#${player.backNumber}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ),
            Expanded(
              child: Text(
                player.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              player.position.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}
