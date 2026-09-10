import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/game.dart';
import '../../data/models/player.dart';
import '../../data/models/player_game_stats.dart';
import '../../data/models/team.dart';
import '../../providers/follow_feed_providers.dart';
import '../../providers/repository_providers.dart';
import '../home/widgets/news_cards.dart';
import '../player/player_detail_screen.dart';
import 'team_hub_screen.dart';

/// 팔로우한 선수 하나에 관한 모든 것을 모아 보여주는 화면.
///
/// 프로필 헤더(사진 자리·이름·소속팀·등번호) 아래로 시즌 요약 → 최근 경기
/// 기록 → 그 선수 기사 순.
class PlayerHubScreen extends ConsumerWidget {
  final Player player;

  const PlayerHubScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teams = ref.watch(teamsProvider).valueOrNull ?? <Team>[];
    final teamById = {for (final t in teams) t.id: t};
    final team = teamById[player.teamId];

    final newsAsync = ref.watch(playerNewsProvider(player));
    final recentAsync = ref.watch(playerRecentStatsProvider(player));
    final seasonAsync = ref.watch(seasonStatsHistoryProvider(player));

    return Scaffold(
      appBar: AppBar(
        title: Text(player.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerDetailScreen(player: player),
              ),
            ),
            child: const Text('상세 기록'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _PlayerHeader(player: player, team: team),
          const SizedBox(height: 20),

          _SectionTitle('이번 시즌'),
          seasonAsync.when(
            loading: () => const _SectionLoading(),
            error: (_, _) => const _SectionEmpty('기록을 불러오지 못했어요'),
            data: (history) {
              if (history.isEmpty) return const _SectionEmpty('시즌 기록이 없어요');
              final s = history.first;
              return Row(
                children: [
                  _BigStat(label: '득점', value: s.points.toStringAsFixed(1)),
                  _BigStat(label: '리바운드', value: s.reb.toStringAsFixed(1)),
                  _BigStat(label: '어시스트', value: s.ast.toStringAsFixed(1)),
                  _BigStat(
                    label: '출전',
                    value: '${s.gamesPlayed}',
                    suffix: '경기',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),

          _SectionTitle('최근 경기 기록'),
          recentAsync.when(
            loading: () => const _SectionLoading(),
            error: (_, _) => const _SectionEmpty('경기 기록을 불러오지 못했어요'),
            data: (rows) => rows.isEmpty
                ? const _SectionEmpty('최근 출전 기록이 없어요')
                : Column(
                    children: [
                      const _RecentHeader(),
                      for (final row in rows)
                        _RecentRow(
                          game: row.game,
                          stats: row.stats,
                          teamId: player.teamId,
                          teamById: teamById,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 22),

          _SectionTitle('${player.name} 뉴스'),
          newsAsync.when(
            loading: () => const _SectionLoading(),
            error: (_, _) => const _SectionEmpty('뉴스를 불러오지 못했어요'),
            data: (articles) {
              if (articles.isEmpty) {
                return const _SectionEmpty('아직 이 선수 이름이 실린 기사가 없어요');
              }
              final headline = articles.first;
              final rest = articles.skip(1).toList();
              return Column(
                children: [
                  NewsHeadlineCard(
                    article: headline,
                    team: teamById[headline.relatedTeamId],
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < rest.length; i++) ...[
                    if (i > 0) const Divider(height: 22),
                    NewsRow(
                      article: rest[i],
                      team: teamById[rest[i].relatedTeamId],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 사진 자리 + 이름 + 소속팀·포지션·등번호.
class _PlayerHeader extends StatelessWidget {
  final Player player;
  final Team? team;

  const _PlayerHeader({required this.player, required this.team});

  @override
  Widget build(BuildContext context) {
    final accent = team?.primaryColor ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // 실제 선수 사진이 준비되면 이 자리를 이미지로 바꾼다.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${player.backNumber}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (team != null)
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TeamHubScreen(team: team!),
                      ),
                    ),
                    child: Text(
                      '${team!.name} · ${player.position.label} · #${player.backNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  )
                else
                  Text(
                    '${player.position.label} · #${player.backNumber}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;

  const _BigStat({required this.label, required this.value, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentHeader extends StatelessWidget {
  const _RecentHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textTertiary,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Expanded(flex: 4, child: Text('상대', style: style)),
          const Expanded(child: Text('분', textAlign: TextAlign.end, style: style)),
          const Expanded(child: Text('득점', textAlign: TextAlign.end, style: style)),
          const Expanded(child: Text('리바', textAlign: TextAlign.end, style: style)),
          const Expanded(child: Text('AS', textAlign: TextAlign.end, style: style)),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final Game game;
  final PlayerGameStats stats;
  final String teamId;
  final Map<String, Team> teamById;

  const _RecentRow({
    required this.game,
    required this.stats,
    required this.teamId,
    required this.teamById,
  });

  @override
  Widget build(BuildContext context) {
    final isHome = game.homeTeamId == teamId;
    final opponentId = isHome ? game.awayTeamId : game.homeTeamId;
    final opponent = teamById[opponentId]?.shortName ?? opponentId;
    final won = teamWon(game, teamId);

    const value = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Text(
                  won ? '승' : '패',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: won ? AppColors.positive : AppColors.negative,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${isHome ? 'vs' : '@'} $opponent',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text('${stats.minutes}', textAlign: TextAlign.end, style: value),
          ),
          Expanded(
            child: Text('${stats.points}', textAlign: TextAlign.end, style: value),
          ),
          Expanded(
            child: Text(
              '${stats.oreb + stats.dreb}',
              textAlign: TextAlign.end,
              style: value,
            ),
          ),
          Expanded(
            child: Text('${stats.ast}', textAlign: TextAlign.end, style: value),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    ),
  );
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}

class _SectionEmpty extends StatelessWidget {
  final String text;

  const _SectionEmpty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
    ),
  );
}
