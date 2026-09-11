import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/team.dart';
import '../../data/models/team_season_stats.dart';
import '../../data/models/team_standing.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/team_logo_placeholder.dart';
import 'team_detail_screen.dart';

/// 탐색 - 팀 순위 화면: 승/패/승률/게임차 + 득점/리바운드/야투% 등 상세 팀 기록.
/// NBA는 동부·서부 컨퍼런스별로 표를 나눠 각각 1위부터 매긴다.
/// 팀 칸은 왼쪽에 고정하고 나머지 스탯은 가로로 스크롤한다. 스탯 헤더를
/// 탭하면 그 표 안에서 그 항목 기준으로 다시 정렬된다.
class StandingsScreen extends ConsumerWidget {
  const StandingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(standingsProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final statsAsync = ref.watch(teamSeasonStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('팀 순위')),
      body: teamsAsync.when(
        loading: () => const _Loading(),
        error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
        data: (teams) {
          final teamById = {for (final t in teams) t.id: t};
          return standingsAsync.when(
            loading: () => const _Loading(),
            error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
            data: (standings) => statsAsync.when(
              loading: () => const _Loading(),
              error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
              data: (stats) {
                final statsByTeam = {for (final s in stats) s.teamId: s};
                // 30팀이면 화면을 넘으므로 세로로 스크롤한다.
                return ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    for (final group in groupStandings(standings)) ...[
                      if (group.title != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          child: Text(
                            group.title!,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      _StandingsTable(
                        key: ValueKey(group.title),
                        standings: group.rows,
                        teamById: teamById,
                        statsByTeam: statsByTeam,
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _Col {
  final String label;
  final double width;
  final String Function(TeamStanding, TeamSeasonStats) value;
  final num Function(TeamStanding, TeamSeasonStats) sortValue;

  const _Col(this.label, this.value, this.sortValue, {this.width = 54});
}

String _f1(double v) => v.toStringAsFixed(1);
String _pct(double ratio) => (ratio * 100).toStringAsFixed(1);

final _columns = <_Col>[
  _Col('승', (s, _) => '${s.wins}', (s, _) => s.wins),
  _Col('패', (s, _) => '${s.losses}', (s, _) => s.losses),
  _Col(
    '승률',
    (s, _) => s.winPct.toStringAsFixed(3),
    (s, _) => s.winPct,
    width: 62,
  ),
  _Col(
    'GB',
    (s, _) => s.gamesBehind == 0 ? '-' : _f1(s.gamesBehind),
    (s, _) => s.gamesBehind,
  ),
  _Col('경기', (s, _) => '${s.gamesPlayed}', (s, _) => s.gamesPlayed),
  _Col('득점', (_, t) => _f1(t.pointsFor), (_, t) => t.pointsFor, width: 56),
  _Col(
    '실점',
    (_, t) => _f1(t.pointsAgainst),
    (_, t) => t.pointsAgainst,
    width: 56,
  ),
  _Col(
    '리바운드',
    (_, t) => _f1(t.rebounds),
    (_, t) => t.rebounds,
    width: 68,
  ),
  _Col('어시스트', (_, t) => _f1(t.assists), (_, t) => t.assists, width: 68),
  _Col('스틸', (_, t) => _f1(t.steals), (_, t) => t.steals),
  _Col('블록', (_, t) => _f1(t.blocks), (_, t) => t.blocks),
  _Col('야투', (_, t) => _f1(t.fgm), (_, t) => t.fgm),
  _Col('야투%', (_, t) => _pct(t.fgPct), (_, t) => t.fgPct, width: 60),
  _Col('3점', (_, t) => _f1(t.tpm), (_, t) => t.tpm),
  _Col('3점%', (_, t) => _pct(t.tpPct), (_, t) => t.tpPct, width: 60),
  _Col('자유투', (_, t) => _f1(t.ftm), (_, t) => t.ftm, width: 60),
  _Col('자유투%', (_, t) => _pct(t.ftPct), (_, t) => t.ftPct, width: 68),
  _Col(
    '공격리바운드',
    (_, t) => _f1(t.oreb),
    (_, t) => t.oreb,
    width: 90,
  ),
  _Col(
    '수비리바운드',
    (_, t) => _f1(t.dreb),
    (_, t) => t.dreb,
    width: 90,
  ),
  _Col('턴오버', (_, t) => _f1(t.tov), (_, t) => t.tov, width: 60),
  _Col('파울', (_, t) => _f1(t.pf), (_, t) => t.pf),
];

const _teamColWidth = 168.0;
const _rowHeight = 56.0;
const _headerHeight = 34.0;

class _StandingsTable extends StatefulWidget {
  final List<TeamStanding> standings;
  final Map<String, Team> teamById;
  final Map<String, TeamSeasonStats> statsByTeam;

  const _StandingsTable({
    super.key,
    required this.standings,
    required this.teamById,
    required this.statsByTeam,
  });

  @override
  State<_StandingsTable> createState() => _StandingsTableState();
}

class _StandingsTableState extends State<_StandingsTable> {
  // null이면 기본(순위순) 정렬.
  int? _sortColIndex;
  bool _desc = true;

  void _onHeaderTap(int index) {
    setState(() {
      if (_sortColIndex == index) {
        _desc = !_desc;
      } else {
        _sortColIndex = index;
        _desc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.standings
        .where(
          (s) =>
              widget.teamById.containsKey(s.teamId) &&
              widget.statsByTeam.containsKey(s.teamId),
        )
        .toList();

    if (_sortColIndex != null) {
      final col = _columns[_sortColIndex!];
      rows.sort((a, b) {
        final va = col.sortValue(a, widget.statsByTeam[a.teamId]!);
        final vb = col.sortValue(b, widget.statsByTeam[b.teamId]!);
        return _desc ? vb.compareTo(va) : va.compareTo(vb);
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ClipRRect(
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
              // 왼쪽 고정 칸: 순위 + 팀
              Container(
                width: _teamColWidth,
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  children: [
                    Container(
                      height: _headerHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 14),
                      child: Text(
                        '팀',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (var i = 0; i < rows.length; i++)
                      _TeamCell(rank: i + 1, team: widget.teamById[rows[i].teamId]!),
                  ],
                ),
              ),
              // 오른쪽 스크롤 영역: 승/패/승률부터 파울까지. 헤더를 탭하면
              // 그 항목 기준으로 정렬이 바뀐다.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: _headerHeight,
                        child: Row(
                          children: [
                            for (var i = 0; i < _columns.length; i++)
                              _HeaderCell(
                                col: _columns[i],
                                active: _sortColIndex == i,
                                desc: _desc,
                                onTap: () => _onHeaderTap(i),
                              ),
                          ],
                        ),
                      ),
                      for (final row in rows)
                        SizedBox(
                          height: _rowHeight,
                          child: Row(
                            children: [
                              for (var i = 0; i < _columns.length; i++)
                                _ValueCell(
                                  col: _columns[i],
                                  row: row,
                                  stats: widget.statsByTeam[row.teamId]!,
                                  active: _sortColIndex == i,
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
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final _Col col;
  final bool active;
  final bool desc;
  final VoidCallback onTap;

  const _HeaderCell({
    required this.col,
    required this.active,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: col.width,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 6),
        color: active ? AppColors.primary.withValues(alpha: 0.08) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              Icon(
                desc ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                size: 16,
                color: AppColors.primary,
              ),
            Text(
              col.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: active ? AppColors.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  final _Col col;
  final TeamStanding row;
  final TeamSeasonStats stats;
  final bool active;

  const _ValueCell({
    required this.col,
    required this.row,
    required this.stats,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: col.width,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withValues(alpha: 0.05) : null,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        col.value(row, stats),
        style: (active || col.label == '승률')
            ? const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )
            : Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _TeamCell extends StatelessWidget {
  final int rank;
  final Team team;

  const _TeamCell({required this.rank, required this.team});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: rank <= 4 ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          TeamLogoPlaceholder(team: team, size: 28),
          const SizedBox(width: 8),
          // 팀 이름을 탭했을 때만 팀 상세로 이동한다(로고/행 전체는 반응하지 않음).
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TeamDetailScreen(team: team),
                  ),
                );
              },
              child: Text(
                team.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 13),
              ),
            ),
          ),
        ],
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
