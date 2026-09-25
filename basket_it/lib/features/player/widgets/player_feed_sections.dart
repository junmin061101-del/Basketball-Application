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
              : _RecentGamesTable(
                  rows: rows,
                  teamId: player.teamId,
                  teamById: teamById,
                ),
        );
  }
}

/// 최근 경기 기록표.
///
/// 왼쪽 상대 칸은 고정하고, 나머지 기록은 가로로 스크롤한다. 시즌별 기록표와
/// 같은 항목을 같은 순서로 둬서 두 표를 나란히 읽을 수 있게 한다.
class _RecentGamesTable extends StatelessWidget {
  final List<({Game game, PlayerGameStats stats})> rows;
  final String teamId;
  final Map<String, Team> teamById;

  const _RecentGamesTable({
    required this.rows,
    required this.teamId,
    required this.teamById,
  });

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textTertiary,
    );
    const valueStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽 고정: 승패 · 날짜 · 상대
            Container(
              width: 132,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Container(
                    height: _recentHeaderHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: const Text('상대', style: headerStyle),
                  ),
                  for (final row in rows)
                    Container(
                      height: _recentRowHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 12, right: 6),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      // 상대 칸을 누르면 그 경기 상세로 간다.
                      child: InkWell(
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
                        child: _OpponentCell(
                          game: row.game,
                          teamId: teamId,
                          teamById: teamById,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: _recentHeaderHeight,
                      child: Row(
                        children: [
                          for (final col in _recentColumns)
                            SizedBox(
                              width: col.width,
                              child: Text(
                                col.label,
                                textAlign: TextAlign.center,
                                style: headerStyle,
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final row in rows)
                      SizedBox(
                        height: _recentRowHeight,
                        child: Row(
                          children: [
                            for (final col in _recentColumns)
                              Container(
                                width: col.width,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                child: Text(
                                  col.value(row.stats),
                                  textAlign: TextAlign.center,
                                  style: col.emphasize
                                      ? valueStyle.copyWith(
                                          fontWeight: FontWeight.w800,
                                        )
                                      : valueStyle,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _recentHeaderHeight = 34.0;
const _recentRowHeight = 44.0;

class _RecentCol {
  final String label;
  final double width;
  final String Function(PlayerGameStats) value;
  final bool emphasize;

  const _RecentCol(
    this.label,
    this.value, {
    this.width = 62,
    this.emphasize = false,
  });
}

String _pct(double ratio) => (ratio * 100).toStringAsFixed(1);

/// 시즌별 기록표와 같은 항목을 같은 순서로 둔다.
final _recentColumns = <_RecentCol>[
  _RecentCol('시간', (s) => s.playTimeLabel, width: 66),
  _RecentCol('득점', (s) => '${s.points}', emphasize: true),
  _RecentCol('야투 성공', (s) => '${s.fgm}', width: 80),
  _RecentCol('야투 시도', (s) => '${s.fga}', width: 80),
  _RecentCol('야투율', (s) => _pct(s.fgPct), width: 66),
  _RecentCol('3점 성공', (s) => '${s.tpm}', width: 76),
  _RecentCol('3점 시도', (s) => '${s.tpa}', width: 76),
  _RecentCol('3점슛률', (s) => _pct(s.tpPct), width: 72),
  _RecentCol('자유투 성공', (s) => '${s.ftm}', width: 90),
  _RecentCol('자유투 시도', (s) => '${s.fta}', width: 90),
  _RecentCol('자유투율', (s) => _pct(s.ftPct), width: 74),
  _RecentCol('공격 리바', (s) => '${s.oreb}', width: 80),
  _RecentCol('수비 리바', (s) => '${s.dreb}', width: 80),
  _RecentCol('리바운드', (s) => '${s.reb}', width: 74),
  _RecentCol('어시스트', (s) => '${s.ast}', width: 74),
  _RecentCol('턴오버', (s) => '${s.tov}', width: 66),
  _RecentCol('스틸', (s) => '${s.stl}'),
  _RecentCol('블록', (s) => '${s.blk}'),
  _RecentCol('파울', (s) => '${s.pf}'),
  _RecentCol('득실마진', (s) {
    final pm = s.plusMinus;
    if (pm == null) return '-';
    return pm > 0 ? '+$pm' : '$pm';
  }, width: 74),
];

/// 왼쪽 고정 칸: 승/패 · 날짜 · 상대 팀.
class _OpponentCell extends StatelessWidget {
  final Game game;
  final String teamId;
  final Map<String, Team> teamById;

  const _OpponentCell({
    required this.game,
    required this.teamId,
    required this.teamById,
  });

  @override
  Widget build(BuildContext context) {
    final isHome = game.homeTeamId == teamId;
    final opponentId = isHome ? game.awayTeamId : game.homeTeamId;
    final opponent = teamById[opponentId]?.shortName ?? opponentId;
    final won = teamWon(game, teamId);

    return Row(
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
            '${game.startTime.month}/${game.startTime.day} '
            '${isHome ? 'vs' : '@'} $opponent',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
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
