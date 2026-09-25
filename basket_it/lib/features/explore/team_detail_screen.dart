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
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          team.fullName,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 팀 컬러 히어로: 로고 + 팀 이름 + 순위·전적
          Container(
            width: double.infinity,
            color: team.primaryColor,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: TeamLogoPlaceholder(team: team, size: 44),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.fullName,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      standingsAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (standings) {
                          final matches = standings.where(
                            (s) => s.teamId == team.id,
                          );
                          if (matches.isEmpty) return const SizedBox.shrink();
                          // NBA는 컨퍼런스 안 순위("동부 3위")를 쓴다.
                          final rankLabel = rankLabelOf(standings, team.id);
                          final row = matches.first;
                          return Text(
                            '$rankLabel · ${row.wins}승 ${row.losses}패',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                standingsAsync.when(
                  loading: () => const _Loading(),
                  error: (err, _) => Text('불러오지 못했어요: $err'),
                  data: (standings) {
                    final matches = standings.where((s) => s.teamId == team.id);
                    if (matches.isEmpty) return const SizedBox.shrink();
                    return _TeamStatCard(
                      standing: matches.first,
                      accent: team.primaryColor,
                    );
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
          ),
        ],
      ),
    );
  }
}

class _TeamStatCard extends StatelessWidget {
  final TeamStanding standing;
  final Color accent;

  const _TeamStatCard({required this.standing, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
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
          MaterialPageRoute(builder: (_) => PlayerDetailScreen(player: player)),
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
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textTertiary),
              ),
            ),
            Expanded(
              child: Text(
                player.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              player.positionText,
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
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
