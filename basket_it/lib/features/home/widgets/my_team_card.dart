import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/game_time.dart';
import '../../../data/models/game.dart';
import '../../../data/models/player_season_stats.dart';
import '../../../data/models/team.dart';
import '../../../data/models/team_standing.dart';
import '../../../providers/my_team_providers.dart';
import '../../../providers/onboarding_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../explore/standings_screen.dart';
import '../../explore/team_list_screen.dart';
import '../../follow/team_hub_screen.dart';
import '../../games/game_detail_screen.dart';
import '../../player/player_detail_screen.dart';
import '../my_team_summary.dart';

/// 홈 맨 위 "내 팀" 영역.
///
/// 지금 리그에서 팔로우한 팀의 순위와 경기 일정·앞뒤 순위·주요 선수를
/// 뉴스보다 먼저 보여준다. 팔로우한 팀이 여럿이면
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

/// 팀 하나의 카드: 팀색 머리 + [경기 | 순위 | 선수] 전환.
class MyTeamCard extends ConsumerStatefulWidget {
  final Team team;

  const MyTeamCard({super.key, required this.team});

  @override
  ConsumerState<MyTeamCard> createState() => _MyTeamCardState();
}

class _MyTeamCardState extends ConsumerState<MyTeamCard> {
  static const _tabs = ['경기', '순위', '선수'];
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final summaryAsync = ref.watch(myTeamSummaryProvider(team.id));
    final season = ref.watch(standingsSeasonProvider).valueOrNull;
    final teamById = {
      for (final t in ref.watch(teamsProvider).valueOrNull ?? const <Team>[])
        t.id: t,
    };

    return Container(
      clipBehavior: Clip.antiAlias,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(team: team, summary: summaryAsync.valueOrNull),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: _Segmented(
              labels: _tabs,
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          summaryAsync.when(
            loading: () => const SizedBox(
              height: 200,
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
            data: (summary) => switch (_tab) {
              0 => _ScheduleList(
                team: team,
                games: summary.schedule,
                teamById: teamById,
              ),
              1 => _NearbyStandings(
                summary: summary,
                teamById: teamById,
                seasonCaption: season?.caption,
              ),
              _ => _TopPlayers(team: team),
            },
          ),
          _FooterLink(
            label: const ['전체 일정', '전체 순위', '선수단 전체'][_tab],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _tab == 1
                    ? const StandingsScreen()
                    : TeamHubScreen(team: team),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 팀색 띠: "2위 · 35승 19패 · 3연승" / 팀 이름 / 팀 정보 바로가기.
class _Header extends StatelessWidget {
  final Team team;
  final MyTeamSummary? summary;

  const _Header({required this.team, required this.summary});

  @override
  Widget build(BuildContext context) {
    // 팀색이 밝으면(노랑 등) 흰 글자가 안 보인다.
    final onColor =
        ThemeData.estimateBrightnessForColor(team.primaryColor) ==
            Brightness.dark
        ? Colors.white
        : Colors.black;
    final s = summary;
    final caption = s == null
        ? '내 팀'
        : [
            s.rankLabel ?? '순위 집계 전',
            if (s.rank != null) '${s.wins}승 ${s.losses}패',
            ?s.streakLabel,
          ].join(' · ');

    return Material(
      color: team.primaryColor,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => TeamHubScreen(team: team))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caption,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: onColor.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                team.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: onColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '팀 정보',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: onColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right, size: 18, color: onColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 회색 바탕 위 흰 알약이 고른 칸을 표시하는 전환.
class _Segmented extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const _Segmented({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index
                          ? AppColors.background
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: i == index
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: i == index
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: i == index
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 표 머리줄. 첫 칸은 왼쪽, 나머지는 (제목, 폭)으로 오른쪽 정렬.
class _TableHead extends StatelessWidget {
  final String first;
  final List<(String, double)> rest;

  const _TableHead(this.first, this.rest);

  static const _style = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Expanded(child: Text(first, style: _style)),
          for (final (label, width) in rest)
            SizedBox(
              width: width,
              child: Text(label, textAlign: TextAlign.right, style: _style),
            ),
        ],
      ),
    );
  }
}

const _rowText = TextStyle(
  fontSize: 15,
  color: AppColors.textPrimary,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// 최근 경기 결과와 다가오는 경기.
class _ScheduleList extends StatelessWidget {
  final Team team;
  final List<Game> games;
  final Map<String, Team> teamById;

  const _ScheduleList({
    required this.team,
    required this.games,
    required this.teamById,
  });

  @override
  Widget build(BuildContext context) {
    if (games.isEmpty) return const _Empty('경기 일정이 아직 없어요');
    return Column(
      children: [
        const _TableHead('경기', [('결과', 60)]),
        for (final game in games) _gameRow(context, game),
      ],
    );
  }

  Widget _gameRow(BuildContext context, Game game) {
    final home = teamById[game.homeTeamId];
    final away = teamById[game.awayTeamId];
    final isHome = game.homeTeamId == team.id;
    final opponent = isHome ? away : home;
    final t = game.startTime;
    final mine = isHome ? game.homeScore : game.awayScore;
    final theirs = isHome ? game.awayScore : game.homeScore;
    final won = MyTeamSummary.won(game, team.id);

    Widget scoreWith(String tag, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$mine - $theirs', style: _rowText),
        const SizedBox(width: 8),
        Text(
          tag,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );

    final status = switch (game.status) {
      GameStatus.scheduled => Text(timeLabel(t), style: _rowText),
      GameStatus.live => scoreWith('LIVE', AppColors.live),
      GameStatus.finished => scoreWith(
        won ? '승' : '패',
        won ? AppColors.positive : AppColors.negative,
      ),
    };

    return InkWell(
      onTap: home == null || away == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GameDetailScreen(
                  game: game,
                  homeTeam: home,
                  awayTeam: away,
                ),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text('${t.month}.${t.day}', style: _rowText),
            ),
            SizedBox(
              width: 28,
              child: Text(
                isHome ? 'vs' : '@',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                opponent?.shortName ?? '',
                overflow: TextOverflow.ellipsis,
                style: _rowText.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            status,
          ],
        ),
      ),
    );
  }
}

/// 순위표에서 내 팀 앞뒤 다섯 줄. 내 팀 줄은 팀색으로 옅게 칠한다.
class _NearbyStandings extends StatelessWidget {
  final MyTeamSummary summary;
  final Map<String, Team> teamById;

  /// "2025-26 시즌 최종". 개막 전 지난 시즌 순위를 지금 순위로 오해하지 않게.
  final String? seasonCaption;

  const _NearbyStandings({
    required this.summary,
    required this.teamById,
    required this.seasonCaption,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.nearby.isEmpty) return const _Empty('순위 정보가 아직 없어요');
    final mineColor = teamById[summary.teamId]?.primaryColor;
    return Column(
      children: [
        _TableHead(seasonCaption ?? '${summary.scope} 순위'.trim(), const [
          ('승', 40),
          ('패', 40),
          ('승차', 52),
        ]),
        for (final (rank, row) in summary.nearby)
          _standingRow(rank, row, row.teamId == summary.teamId, mineColor),
      ],
    );
  }

  Widget _standingRow(int rank, TeamStanding row, bool mine, Color? color) {
    final style = _rowText.copyWith(
      fontWeight: mine ? FontWeight.w800 : FontWeight.w400,
    );
    Widget cell(String text, double width) => SizedBox(
      width: width,
      child: Text(text, textAlign: TextAlign.right, style: style),
    );
    return Container(
      color: mine ? color?.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('$rank', style: style)),
          Expanded(
            child: Text(
              teamById[row.teamId]?.shortName ?? '',
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          cell('${row.wins}', 40),
          cell('${row.losses}', 40),
          cell(
            row.gamesBehind == 0 ? '-' : row.gamesBehind.toStringAsFixed(1),
            52,
          ),
        ],
      ),
    );
  }
}

/// 이번 시즌 경기당 득점 상위 다섯 명.
class _TopPlayers extends ConsumerWidget {
  final Team team;

  const _TopPlayers({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(currentSeasonStatsAllProvider);
    final players = {
      for (final p in ref.watch(allPlayersProvider).valueOrNull ?? const [])
        p.id: p,
    };
    if (statsAsync.isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    final top =
        (statsAsync.valueOrNull ?? const <PlayerSeasonStats>[])
            .where((s) => s.teamId == team.id && players[s.playerId] != null)
            .toList()
          ..sort((a, b) => b.points.compareTo(a.points));
    if (top.isEmpty) return const _Empty('이번 시즌 기록이 아직 없어요');

    Widget cell(double v) => SizedBox(
      width: 48,
      child: Text(
        v.toStringAsFixed(1),
        textAlign: TextAlign.right,
        style: _rowText,
      ),
    );

    return Column(
      children: [
        const _TableHead('선수', [('득점', 48), ('리바', 48), ('어시', 48)]),
        for (final s in top.take(5))
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PlayerDetailScreen(player: players[s.playerId]!),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      players[s.playerId]!.name,
                      overflow: TextOverflow.ellipsis,
                      style: _rowText.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  cell(s.points),
                  cell(s.reb),
                  cell(s.ast),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
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
