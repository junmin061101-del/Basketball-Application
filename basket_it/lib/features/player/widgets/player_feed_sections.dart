import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/game.dart';
import '../../../data/models/player.dart';
import '../../../data/models/player_game_stats.dart';
import '../../../data/models/team.dart';
import '../../../providers/follow_feed_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../games/game_detail_screen.dart';
import '../../home/widgets/news_cards.dart';

/// 선수 상세의 "최근 경기 기록". 경기를 누르면 그 경기 상세로 간다.
class PlayerRecentGamesSection extends ConsumerWidget {
  final Player player;

  const PlayerRecentGamesSection({super.key, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamById = {
      for (final t in ref.watch(teamsProvider).valueOrNull ?? const <Team>[])
        t.id: t,
    };
    return ref
        .watch(playerRecentStatsProvider(player))
        .when(
          loading: () => const _SectionLoading(),
          error: (_, _) => const _SectionEmpty('경기 기록을 불러오지 못했어요'),
          data: (rows) => rows.isEmpty
              ? const _SectionEmpty('최근 출전 기록이 없어요')
              : Column(
                  children: [
                    const _RecentHeader(),
                    for (final row in rows)
                      InkWell(
                        onTap: () {
                          final home = teamById[row.game.homeTeamId];
                          final away = teamById[row.game.awayTeamId];
                          if (home == null || away == null) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GameDetailScreen(
                                game: row.game,
                                homeTeam: home,
                                awayTeam: away,
                              ),
                            ),
                          );
                        },
                        child: _RecentRow(
                          game: row.game,
                          stats: row.stats,
                          teamId: player.teamId,
                          teamById: teamById,
                        ),
                      ),
                  ],
                ),
        );
  }
}

/// 선수 상세의 "뉴스": 제목·요약에 선수 이름이 나오는 기사.
class PlayerNewsSection extends ConsumerWidget {
  final Player player;

  const PlayerNewsSection({super.key, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamById = {
      for (final t in ref.watch(teamsProvider).valueOrNull ?? const <Team>[])
        t.id: t,
    };
    return ref
        .watch(playerNewsProvider(player))
        .when(
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
          const Expanded(
            child: Text('분', textAlign: TextAlign.end, style: style),
          ),
          const Expanded(
            child: Text('득점', textAlign: TextAlign.end, style: style),
          ),
          const Expanded(
            child: Text('리바', textAlign: TextAlign.end, style: style),
          ),
          const Expanded(
            child: Text('AS', textAlign: TextAlign.end, style: style),
          ),
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
                    '${game.startTime.month}/${game.startTime.day} ${isHome ? 'vs' : '@'} $opponent',
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
            child: Text(
              '${stats.minutes}',
              textAlign: TextAlign.end,
              style: value,
            ),
          ),
          Expanded(
            child: Text(
              '${stats.points}',
              textAlign: TextAlign.end,
              style: value,
            ),
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
