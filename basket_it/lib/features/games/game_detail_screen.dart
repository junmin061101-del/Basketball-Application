import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/game_time.dart';
import '../../data/models/game.dart';
import '../../data/models/live_game_state.dart';
import '../../data/models/player.dart';
import '../../data/models/player_game_stats.dart';
import '../../data/models/team.dart';
import '../../data/models/team_season_stats.dart';
import '../../providers/follow_feed_providers.dart';
import '../../providers/game_providers.dart';
import '../../providers/live_box_score_providers.dart';
import '../../providers/live_game_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/team_logo_placeholder.dart';
import '../explore/team_detail_screen.dart';
import '../player/player_detail_screen.dart';

/// 경기 상세 화면: 스코어보드 + 이 경기 최고 활약 + 양 팀 기록 비교 + 박스스코어.
class GameDetailScreen extends ConsumerWidget {
  /// 목록에서 넘어올 때의 경기. 진행 중이면 실시간 상태를 덮어써서 쓴다.
  final Game game;
  final Team homeTeam;
  final Team awayTeam;

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.homeTeam,
    required this.awayTeam,
  });

  /// 상단 제목. 지난 시즌 경기는 몇 년 경기인지 알 수 있게 연도를 붙인다.
  static String dateTitle(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final label = '${date.month}월 ${date.day}일';
    return date.year == today.year ? label : '${date.year}년 $label';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 화면을 보고 있는 동안 점수가 바뀌도록 실시간 상태를 씌운다.
    final live = ref.watch(liveGameStatesProvider).valueOrNull ?? const {};
    final game = applyLiveState(
      this.game,
      live,
      ref.watch(selectedLeagueProvider),
    );
    final boxScoreAsync = ref.watch(boxScoreProvider(game));
    // 경기 중에는 서버가 30초마다 적어 주는 기록을 쓴다.
    final liveLines = ref.watch(liveBoxScoreProvider(game)).valueOrNull ?? const [];
    final playersAsync = ref.watch(allPlayersProvider);
    final standings = ref.watch(standingsProvider).valueOrNull ?? const [];
    final recordByTeam = {
      for (final s in standings)
        if (s.gamesPlayed > 0) s.teamId: '${s.wins}승 ${s.losses}패',
    };

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              dateTitle(game.date),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _Scoreboard(
              game: game,
              homeTeam: homeTeam,
              awayTeam: awayTeam,
              homeRecord: recordByTeam[homeTeam.id],
              awayRecord: recordByTeam[awayTeam.id],
            ),
            const SizedBox(height: 28),
            if (game.status == GameStatus.scheduled)
              _UpcomingBody(homeTeam: homeTeam, awayTeam: awayTeam)
            else
              playersAsync.when(
                loading: () => const _SectionLoading(),
                error: (err, _) => Text('불러오지 못했어요: $err'),
                data: (players) {
                  final playerById = {for (final p in players) p.id: p};
                  return boxScoreAsync.when(
                    loading: () => const _SectionLoading(),
                    error: (err, _) => Text('불러오지 못했어요: $err'),
                    data: (stored) => _GameBody(
                      game: game,
                      homeTeam: homeTeam,
                      awayTeam: awayTeam,
                      boxScore: chooseBoxScore(
                        stored: stored,
                        live: liveLines,
                        status: game.status,
                      ),
                      playerById: playerById,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  final Game game;
  final Team homeTeam;
  final Team awayTeam;

  /// "5승 2패". 순위표가 아직 없으면 null.
  final String? homeRecord;
  final String? awayRecord;

  const _Scoreboard({
    required this.game,
    required this.homeTeam,
    required this.awayTeam,
    this.homeRecord,
    this.awayRecord,
  });

  @override
  Widget build(BuildContext context) {
    final showScore = game.status != GameStatus.scheduled;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _StatusLine(game: game),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TeamScoreColumn(
                  team: homeTeam,
                  score: game.homeScore,
                  record: homeRecord,
                  showScore: showScore,
                ),
              ),
              // 시작 전에는 점수 자리가 비므로 가운데에 팁오프 시각을 크게 둔다.
              if (!showScore)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    timeLabel(game.startTime),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'VS',
                  style: TextStyle(
                      color: AppColors.textTertiary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              Expanded(
                child: _TeamScoreColumn(
                  team: awayTeam,
                  score: game.awayScore,
                  record: awayRecord,
                  showScore: showScore,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 스코어보드 맨 위의 상태 한 줄(LIVE · 3쿼터 / 경기 종료 / 경기 예정).
class _StatusLine extends StatelessWidget {
  final Game game;

  const _StatusLine({required this.game});

  @override
  Widget build(BuildContext context) {
    if (game.status == GameStatus.live) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.live,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE${game.liveClock == null ? '' : ' · ${game.liveClock}'}',
            style: const TextStyle(
              color: AppColors.live,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      );
    }
    return Text(
      game.status == GameStatus.finished
          ? '경기 종료'
          : '경기 예정 · ${dayLabel(game.startTime)}',
      style: const TextStyle(
        color: AppColors.textTertiary,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }
}

class _TeamScoreColumn extends StatelessWidget {
  final Team team;
  final int score;
  final String? record;
  final bool showScore;

  const _TeamScoreColumn({
    required this.team,
    required this.score,
    required this.showScore,
    this.record,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          TeamLogoPlaceholder(team: team, size: 56),
          const SizedBox(height: 10),
          // 팀 이름을 탭했을 때만 팀 상세로 이동한다(로고/점수는 반응하지 않음).
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TeamDetailScreen(team: team)),
              );
            },
            child: Text(
              // "울산 현대모비스"가 낱말 가운데서 잘리지 않게 연고지와 팀 이름을
              // 각각 한 줄로 둔다.
              team.fullName.replaceFirst(' ', '\n'),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(height: 1.25),
            ),
          ),
          if (record != null) ...[
            const SizedBox(height: 4),
            Text(
              record!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const SizedBox(height: 6),
          if (showScore)
            Text(
              '$score',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
        ],
      ),
    );
  }
}

/// 아직 시작하지 않은 경기의 본문.
///
/// 점수도 기록도 없는 화면이 비어 보이지 않도록, 경기를 기다리며 볼 만한 것을
/// 둔다: 두 팀의 최근 결과, 올 시즌 맞대결, 시즌 평균 비교.
class _UpcomingBody extends ConsumerWidget {
  final Team homeTeam;
  final Team awayTeam;

  const _UpcomingBody({required this.homeTeam, required this.awayTeam});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeForm = ref
        .watch(recentResultsProvider((teamId: homeTeam.id, limit: 5)))
        .valueOrNull;
    final awayForm = ref
        .watch(recentResultsProvider((teamId: awayTeam.id, limit: 5)))
        .valueOrNull;
    final headToHead = ref
        .watch(
          headToHeadProvider((teamId: homeTeam.id, opponentId: awayTeam.id)),
        )
        .valueOrNull;
    final seasonStats = ref.watch(teamSeasonStatsProvider).valueOrNull;
    final statsById = {for (final s in seasonStats ?? const []) s.teamId: s};
    final homeStats = statsById[homeTeam.id];
    final awayStats = statsById[awayTeam.id];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (homeForm != null && awayForm != null) ...[
          const _SectionTitle('최근 5경기'),
          const SizedBox(height: 12),
          _FormCard(team: homeTeam, games: homeForm),
          const SizedBox(height: 10),
          _FormCard(team: awayTeam, games: awayForm),
          const SizedBox(height: 28),
        ],
        if (headToHead != null && headToHead.isNotEmpty) ...[
          const _SectionTitle('맞대결'),
          const SizedBox(height: 12),
          _HeadToHeadCard(
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            games: headToHead,
          ),
          const SizedBox(height: 28),
        ],
        if (homeStats != null && awayStats != null) ...[
          const _SectionTitle('시즌 평균 비교'),
          const SizedBox(height: 12),
          _SeasonComparison(home: homeStats, away: awayStats),
          const SizedBox(height: 24),
        ],
        Text(
          '경기가 시작하면 실시간 점수와 선수 기록이 여기에 표시돼요.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// 한 팀의 최근 결과를 승·패 알약으로 늘어놓는다(왼쪽이 가장 최근).
class _FormCard extends StatelessWidget {
  final Team team;
  final List<Game> games;

  const _FormCard({required this.team, required this.games});

  @override
  Widget build(BuildContext context) {
    final wins = games.where((g) => teamWon(g, team.id)).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          TeamLogoPlaceholder(team: team, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              team.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (games.isEmpty)
            Text('기록 없음', style: Theme.of(context).textTheme.bodySmall)
          else ...[
            Text(
              '$wins승 ${games.length - wins}패',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 10),
            for (final game in games) ...[
              const SizedBox(width: 4),
              _ResultPill(won: teamWon(game, team.id)),
            ],
          ],
        ],
      ),
    );
  }
}

class _ResultPill extends StatelessWidget {
  final bool won;

  const _ResultPill({required this.won});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: won ? AppColors.positive : AppColors.negative,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        won ? '승' : '패',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 올 시즌 두 팀이 붙은 경기들.
class _HeadToHeadCard extends StatelessWidget {
  final Team homeTeam;
  final Team awayTeam;
  final List<Game> games;

  const _HeadToHeadCard({
    required this.homeTeam,
    required this.awayTeam,
    required this.games,
  });

  @override
  Widget build(BuildContext context) {
    final homeWins = games.where((g) => teamWon(g, homeTeam.id)).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$homeWins',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '올 시즌 상대 전적',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                '${games.length - homeWins}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          for (final game in games) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    dayLabel(game.startTime),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                Text(
                  '${game.homeScore} : ${game.awayScore}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 두 팀의 시즌 평균(경기당)을 같은 막대로 비교한다.
class _SeasonComparison extends StatelessWidget {
  final TeamSeasonStats home;
  final TeamSeasonStats away;

  const _SeasonComparison({required this.home, required this.away});

  @override
  Widget build(BuildContext context) {
    final rows = <_CompareRowData>[
      _CompareRowData('득점', home.pointsFor, away.pointsFor),
      _CompareRowData('실점', home.pointsAgainst, away.pointsAgainst),
      _CompareRowData('리바운드', home.rebounds, away.rebounds),
      _CompareRowData('어시스트', home.assists, away.assists),
      _CompareRowData('스틸', home.steals, away.steals),
      _CompareRowData('블록', home.blocks, away.blocks),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const SizedBox(height: 16),
            _CompareRow(
              data: row,
              homeColor: AppColors.textPrimary,
              awayColor: AppColors.accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _GameBody extends StatelessWidget {
  final Game game;
  final Team homeTeam;
  final Team awayTeam;
  final List<PlayerGameStats> boxScore;
  final Map<String, Player> playerById;

  const _GameBody({
    required this.game,
    required this.homeTeam,
    required this.awayTeam,
    required this.boxScore,
    required this.playerById,
  });

  @override
  Widget build(BuildContext context) {
    // 지난 3시즌 경기까지 박스스코어를 보관해 두지만, 아직 받지 못한 경기는
    // 빈 화면 대신 그 사실을 알려 준다.
    if (boxScore.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            '이 경기의 선수 기록이 아직 없어요.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final homeLines = boxScore.where((s) => s.teamId == homeTeam.id).toList()
      ..sort((a, b) => b.points.compareTo(a.points));
    final awayLines = boxScore.where((s) => s.teamId == awayTeam.id).toList()
      ..sort((a, b) => b.points.compareTo(a.points));

    final topLine = [
      ...homeLines,
      ...awayLines,
    ].reduce((a, b) => a.points >= b.points ? a : b);
    final topPlayer = playerById[topLine.playerId];
    final topTeam = topLine.teamId == homeTeam.id ? homeTeam : awayTeam;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topPlayer != null) ...[
          const _SectionTitle('Best Player'),
          const SizedBox(height: 12),
          _TopPerformerCard(player: topPlayer, team: topTeam, stats: topLine),
          const SizedBox(height: 28),
        ],
        const _SectionTitle('팀 기록 비교'),
        const SizedBox(height: 12),
        _TeamComparison(
          homeTeam: homeTeam,
          awayTeam: awayTeam,
          homeLines: homeLines,
          awayLines: awayLines,
          homeScore: game.homeScore,
          awayScore: game.awayScore,
        ),
        const SizedBox(height: 28),
        const _SectionTitle('선수 기록'),
        const SizedBox(height: 10),
        _BoxScoreSection(
          homeTeam: homeTeam,
          awayTeam: awayTeam,
          homeLines: homeLines,
          awayLines: awayLines,
          playerById: playerById,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

/// 그날 가장 활약한 선수는 카드를 더 크게 강조해서 보여준다.
class _TopPerformerCard extends StatelessWidget {
  final Player player;
  final Team team;
  final PlayerGameStats stats;

  const _TopPerformerCard({
    required this.player,
    required this.team,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PlayerDetailScreen(player: player, gameStats: stats),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${team.fullName} · ${player.positionText}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MiniStat(label: '리바운드', value: '${stats.reb}'),
                      const SizedBox(width: 14),
                      _MiniStat(label: '어시스트', value: '${stats.ast}'),
                      const SizedBox(width: 14),
                      _MiniStat(
                        label: '야투',
                        value: '${stats.fgm}/${stats.fga}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 66,
              height: 66,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.sky.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${stats.points}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: AppColors.sky,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'PTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sky.withValues(alpha: 0.8),
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

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withValues(alpha: 0.55),
        ),
        children: [
          TextSpan(
            text: '$value ',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          TextSpan(text: label),
        ],
      ),
    );
  }
}

class _TeamComparison extends StatelessWidget {
  final Team homeTeam;
  final Team awayTeam;
  final List<PlayerGameStats> homeLines;
  final List<PlayerGameStats> awayLines;
  final int homeScore;
  final int awayScore;

  const _TeamComparison({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeLines,
    required this.awayLines,
    required this.homeScore,
    required this.awayScore,
  });

  int _sum(List<PlayerGameStats> lines, int Function(PlayerGameStats) f) =>
      lines.fold(0, (sum, s) => sum + f(s));

  @override
  Widget build(BuildContext context) {
    final rows = <_CompareRowData>[
      _CompareRowData('득점', homeScore, awayScore),
      _CompareRowData(
        '리바운드',
        _sum(homeLines, (s) => s.reb),
        _sum(awayLines, (s) => s.reb),
      ),
      _CompareRowData(
        '어시스트',
        _sum(homeLines, (s) => s.ast),
        _sum(awayLines, (s) => s.ast),
      ),
      _CompareRowData(
        '스틸',
        _sum(homeLines, (s) => s.stl),
        _sum(awayLines, (s) => s.stl),
      ),
      _CompareRowData(
        '블록',
        _sum(homeLines, (s) => s.blk),
        _sum(awayLines, (s) => s.blk),
      ),
      _CompareRowData(
        '턴오버',
        _sum(homeLines, (s) => s.tov),
        _sum(awayLines, (s) => s.tov),
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0) const SizedBox(height: 16),
            // 왼쪽(홈)은 검정, 오른쪽(원정)은 파랑으로 디자인을 따른다.
            _CompareRow(
              data: row,
              homeColor: AppColors.textPrimary,
              awayColor: AppColors.accent,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareRowData {
  final String label;

  /// 한 경기 합계는 정수, 시즌 평균은 소수로 들어온다.
  final num homeValue;
  final num awayValue;

  const _CompareRowData(this.label, this.homeValue, this.awayValue);

  String get homeText => _text(homeValue);
  String get awayText => _text(awayValue);

  static String _text(num value) =>
      value is int ? '$value' : value.toStringAsFixed(1);
}

class _CompareRow extends StatelessWidget {
  final _CompareRowData data;
  final Color homeColor;
  final Color awayColor;

  const _CompareRow({
    required this.data,
    required this.homeColor,
    required this.awayColor,
  });

  @override
  Widget build(BuildContext context) {
    final total = data.homeValue + data.awayValue;
    final homeFraction = total == 0 ? 0.5 : data.homeValue / total;

    const valueStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(data.homeText, style: valueStyle),
            Text(
              data.label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            Text(data.awayText, style: valueStyle),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              Expanded(
                flex: (homeFraction * 1000).round().clamp(1, 999),
                child: Container(height: 5, color: homeColor),
              ),
              Expanded(
                flex: ((1 - homeFraction) * 1000).round().clamp(1, 999),
                child: Container(height: 5, color: awayColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 박스스코어 표의 스탯 칸 하나.
///
/// 선수 이름 칸은 왼쪽에 고정하고, 기록은 가로로 스크롤해 전 항목을 본다.
class _StatCol {
  final String label;
  final double width;
  final String Function(PlayerGameStats) value;
  final bool emphasize;

  /// 팀 안에서 가장 높은 값을 파랗게 칠할 때 쓰는 비교값. null이면 강조하지 않는다.
  final int? Function(PlayerGameStats)? leaderValue;

  const _StatCol(
    this.label,
    this.value, {
    this.width = 46,
    this.emphasize = false,
    this.leaderValue,
  });
}

String _pct(double ratio) => (ratio * 100).toStringAsFixed(1);

// 순서는 네이버 스포츠처럼 많이 보는 기록(득점·리바운드·어시스트·스틸·블락)을
// 앞에 두고, 슛 세부 기록을 뒤에 둔다. 칸은 값이 들어갈 만큼만 좁게 잡아
// 한 화면에 여러 항목이 함께 보이게 한다(머리글은 두 줄로 접힌다).
final _boxScoreColumns = <_StatCol>[
  // "31:04"(KBL) / "22분"(NBA는 분 단위만 온다)
  _StatCol('시간', (s) => s.playTimeLabel, width: 54),
  _StatCol(
    '득점',
    (s) => '${s.points}',
    width: 44,
    emphasize: true,
    leaderValue: (s) => s.points,
  ),
  _StatCol('리바운드', (s) => '${s.reb}', width: 52, leaderValue: (s) => s.reb),
  _StatCol('어시스트', (s) => '${s.ast}', width: 52, leaderValue: (s) => s.ast),
  _StatCol('스틸', (s) => '${s.stl}', width: 40, leaderValue: (s) => s.stl),
  _StatCol('블락', (s) => '${s.blk}', width: 40, leaderValue: (s) => s.blk),
  _StatCol('야투\n성공', (s) => '${s.fgm}', width: 46),
  _StatCol('야투\n시도', (s) => '${s.fga}', width: 46),
  _StatCol('야투율', (s) => _pct(s.fgPct), width: 48),
  _StatCol('3점\n성공', (s) => '${s.tpm}', width: 46),
  _StatCol('3점\n시도', (s) => '${s.tpa}', width: 46),
  _StatCol('3점슛\n성공률', (s) => _pct(s.tpPct), width: 50),
  _StatCol('자유투\n성공', (s) => '${s.ftm}', width: 50),
  _StatCol('자유투\n시도', (s) => '${s.fta}', width: 50),
  _StatCol('자유투\n성공률', (s) => _pct(s.ftPct), width: 50),
  _StatCol('공격\n리바운드', (s) => '${s.oreb}', width: 52),
  _StatCol('수비\n리바운드', (s) => '${s.dreb}', width: 52),
  _StatCol('턴오버', (s) => '${s.tov}', width: 44),
  _StatCol('파울', (s) => '${s.pf}', width: 40),
  _StatCol('득실마진', (s) {
    final pm = s.plusMinus;
    if (pm == null) return '-';
    return pm > 0 ? '+$pm' : '$pm';
  }, width: 52),
];

/// 박스스코어 한 묶음. [title]이 null이면 선발/후보를 모르는 예전 기록이다.
@immutable
class BoxScoreGroup {
  final String? title;
  final List<PlayerGameStats> lines;

  const BoxScoreGroup(this.title, this.lines);
}

/// 한 팀 박스스코어를 "선발" / "후보"로 나눈다. 묶음 안은 출전 시간이 긴 순.
///
/// 선발 표시가 없는 기록(예전에 받은 경기)은 나누지 않고 한 묶음으로 둔다.
List<BoxScoreGroup> groupBoxScore(List<PlayerGameStats> lines) {
  int playTime(PlayerGameStats s) => s.seconds ?? s.minutes * 60;
  final sorted = [...lines]
    ..sort((a, b) {
      final byTime = playTime(b).compareTo(playTime(a));
      return byTime != 0 ? byTime : b.points.compareTo(a.points);
    });
  if (sorted.every((s) => s.starter == null)) {
    return [BoxScoreGroup(null, sorted)];
  }
  final starters = sorted.where((s) => s.starter == true).toList();
  final bench = sorted.where((s) => s.starter != true).toList();
  return [
    if (starters.isNotEmpty) BoxScoreGroup('선발', starters),
    if (bench.isNotEmpty) BoxScoreGroup('후보', bench),
  ];
}

/// 두 팀 중 하나를 버튼으로 골라 그 팀 박스스코어만 보여준다.
class _BoxScoreSection extends StatefulWidget {
  final Team homeTeam;
  final Team awayTeam;
  final List<PlayerGameStats> homeLines;
  final List<PlayerGameStats> awayLines;
  final Map<String, Player> playerById;

  const _BoxScoreSection({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeLines,
    required this.awayLines,
    required this.playerById,
  });

  @override
  State<_BoxScoreSection> createState() => _BoxScoreSectionState();
}

class _BoxScoreSectionState extends State<_BoxScoreSection> {
  bool _showHome = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (final (team, isHome) in [
              (widget.homeTeam, true),
              (widget.awayTeam, false),
            ])
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _TeamChip(
                  team: team,
                  active: _showHome == isHome,
                  onTap: () => setState(() => _showHome = isHome),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _BoxScoreTable(
          key: ValueKey(_showHome),
          lines: _showHome ? widget.homeLines : widget.awayLines,
          playerById: widget.playerById,
        ),
      ],
    );
  }
}

class _TeamChip extends StatelessWidget {
  final Team team;
  final bool active;
  final VoidCallback onTap;

  const _TeamChip({
    required this.team,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.background : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.textPrimary : Colors.transparent,
          ),
        ),
        child: Text(
          team.shortName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: active ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

const _boxScoreRowHeight = 44.0;
// 머리글이 두 줄로 접히는 칸("자유투 성공률")까지 들어가는 높이.
const _boxScoreHeaderHeight = 38.0;

/// 선발·후보로 나눈 박스스코어 표.
///
/// 왼쪽 선수 칸은 고정하고 기록은 가로로 스크롤한다. 팀 안에서 득점·리바운드·
/// 어시스트·스틸·블록이 가장 많은 선수는 그 칸을 파랗게 칠하고 이름 앞에
/// 파란 막대를 둔다.
class _BoxScoreTable extends StatelessWidget {
  final List<PlayerGameStats> lines;
  final Map<String, Player> playerById;

  const _BoxScoreTable({
    super.key,
    required this.lines,
    required this.playerById,
  });

  int _max(int? Function(PlayerGameStats) of) =>
      lines.map((l) => of(l) ?? 0).fold(0, (a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    final groups = groupBoxScore(lines);
    final leaders = {
      for (final col in _boxScoreColumns)
        if (col.leaderValue != null) col.label: _max(col.leaderValue!),
    };
    bool leads(PlayerGameStats line) => _boxScoreColumns.any(
      (col) =>
          col.leaderValue != null &&
          (leaders[col.label] ?? 0) > 0 &&
          col.leaderValue!(line) == leaders[col.label],
    );
    const headerStyle = TextStyle(
      fontSize: 11,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: AppColors.textTertiary,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 왼쪽 고정: 선수 이름
            Container(
              width: _boxScoreNameWidth,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Container(
                    height: _boxScoreHeaderHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: const Text('선수', style: headerStyle),
                  ),
                  for (final group in groups) ...[
                    if (group.title != null) _GroupBand(title: group.title!),
                    for (final line in group.lines)
                      Container(
                        height: _boxScoreRowHeight,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: _BoxScoreNameCell(
                          player: playerById[line.playerId],
                          stats: line,
                          leader: leads(line),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            // 오른쪽: 기록(가로 스크롤)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: _boxScoreHeaderHeight,
                      child: Row(
                        children: [
                          for (final col in _boxScoreColumns)
                            SizedBox(
                              width: col.width,
                              child: Text(
                                col.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: headerStyle,
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final group in groups) ...[
                      if (group.title != null)
                        Container(
                          height: _boxScoreBandHeight,
                          width: _boxScoreColumns.fold<double>(
                            0,
                            (sum, col) => sum + col.width,
                          ),
                          color: AppColors.surfaceElevated,
                        ),
                      for (final line in group.lines)
                        SizedBox(
                          height: _boxScoreRowHeight,
                          child: Row(
                            children: [
                              for (final col in _boxScoreColumns)
                                _ValueCell(
                                  col: col,
                                  stats: line,
                                  isLeader:
                                      col.leaderValue != null &&
                                      (leaders[col.label] ?? 0) > 0 &&
                                      col.leaderValue!(line) ==
                                          leaders[col.label],
                                ),
                            ],
                          ),
                        ),
                    ],
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

class _ValueCell extends StatelessWidget {
  final _StatCol col;
  final PlayerGameStats stats;
  final bool isLeader;

  const _ValueCell({
    required this.col,
    required this.stats,
    required this.isLeader,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: col.width,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        col.value(stats),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isLeader || col.emphasize
              ? FontWeight.w900
              : FontWeight.w600,
          color: isLeader ? AppColors.accent : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _GroupBand extends StatelessWidget {
  final String title;

  const _GroupBand({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _boxScoreBandHeight,
      width: double.infinity,
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

const _boxScoreNameWidth = 106.0;
const _boxScoreBandHeight = 30.0;

class _BoxScoreNameCell extends StatelessWidget {
  final Player? player;
  final PlayerGameStats stats;
  final bool leader;

  const _BoxScoreNameCell({
    required this.player,
    required this.stats,
    required this.leader,
  });

  @override
  Widget build(BuildContext context) {
    // 지난 시즌 경기에는 지금 명단에 없는 선수도 나온다. 박스스코어에 적힌 이름을 쓴다.
    final name = player?.name ?? stats.name ?? '알 수 없음';
    final target = player;
    return InkWell(
      onTap: target == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PlayerDetailScreen(player: target, gameStats: stats),
                ),
              );
            },
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: leader ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
