import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/game.dart';
import '../../data/models/player.dart';
import '../../data/models/player_game_stats.dart';
import '../../data/models/team.dart';
import '../../providers/game_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/team_logo_placeholder.dart';
import '../explore/team_detail_screen.dart';
import '../player/player_detail_screen.dart';

/// 경기 상세 화면: 스코어보드 + 이 경기 최고 활약 + 양 팀 기록 비교 + 박스스코어.
class GameDetailScreen extends ConsumerWidget {
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
    final boxScoreAsync = ref.watch(boxScoreProvider(game));
    final playersAsync = ref.watch(allPlayersProvider);

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
            _Scoreboard(game: game, homeTeam: homeTeam, awayTeam: awayTeam),
            const SizedBox(height: 28),
            if (game.status == GameStatus.scheduled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    '경기 시작 전이에요. 시작하면 실시간 기록이 표시돼요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              playersAsync.when(
                loading: () => const _SectionLoading(),
                error: (err, _) => Text('불러오지 못했어요: $err'),
                data: (players) {
                  final playerById = {for (final p in players) p.id: p};
                  return boxScoreAsync.when(
                    loading: () => const _SectionLoading(),
                    error: (err, _) => Text('불러오지 못했어요: $err'),
                    data: (boxScore) => _GameBody(
                      game: game,
                      homeTeam: homeTeam,
                      awayTeam: awayTeam,
                      boxScore: boxScore,
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

  const _Scoreboard({
    required this.game,
    required this.homeTeam,
    required this.awayTeam,
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
                  showScore: showScore,
                ),
              ),
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
      game.status == GameStatus.finished ? '경기 종료' : '경기 예정',
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
  final bool showScore;

  const _TeamScoreColumn({
    required this.team,
    required this.score,
    required this.showScore,
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
              team.fullName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
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
  final int homeValue;
  final int awayValue;

  const _CompareRowData(this.label, this.homeValue, this.awayValue);
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
            Text('${data.homeValue}', style: valueStyle),
            Text(
              data.label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            Text('${data.awayValue}', style: valueStyle),
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
/// 디자인처럼 화면 너비에 5칸(선수·시간·득점·리바운드·어시스트)을 맞춘다.
/// 더 자세한 기록(야투·3점·턴오버 등)은 선수 상세에서 본다.
class _StatCol {
  final String label;
  final int flex;
  final String Function(PlayerGameStats) value;

  /// 팀 안에서 가장 높은 값을 파랗게 칠할 때 쓰는 비교값. null이면 강조하지 않는다.
  final int? Function(PlayerGameStats)? leaderValue;

  const _StatCol(this.label, this.value, {this.flex = 2, this.leaderValue});
}

final _boxScoreColumns = <_StatCol>[
  // "31:04"(KBL) / "22분"(NBA는 분 단위만 온다)
  _StatCol('시간', (s) => s.playTimeLabel, flex: 3),
  _StatCol('득점', (s) => '${s.points}', leaderValue: (s) => s.points),
  _StatCol('리바운드', (s) => '${s.reb}', flex: 3, leaderValue: (s) => s.reb),
  _StatCol('어시스트', (s) => '${s.ast}', flex: 3, leaderValue: (s) => s.ast),
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
const _boxScoreHeaderHeight = 34.0;

/// 선발·후보 묶음마다 머리줄을 둔 박스스코어 표.
///
/// 팀 안에서 득점·리바운드·어시스트가 가장 많은 선수는 그 칸을 파랗게 칠하고,
/// 이름 앞에 파란 막대를 둔다.
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _HeaderRow(title: '선수'),
            for (final group in groups) ...[
              if (group.title != null) _GroupBand(title: group.title!),
              for (final line in group.lines)
                _BoxScoreRow(
                  stats: line,
                  player: playerById[line.playerId],
                  leaders: leaders,
                  highlightName: leads(line),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String title;

  const _HeaderRow({required this.title});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppColors.textTertiary,
    );
    return Container(
      height: _boxScoreHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(title, style: style)),
          for (final col in _boxScoreColumns)
            Expanded(
              flex: col.flex,
              child: Text(col.label, textAlign: TextAlign.center, style: style),
            ),
        ],
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
      height: 30,
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

class _BoxScoreRow extends StatelessWidget {
  final PlayerGameStats stats;
  final Player? player;
  final Map<String, int> leaders;
  final bool highlightName;

  const _BoxScoreRow({
    required this.stats,
    required this.player,
    required this.leaders,
    required this.highlightName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _boxScoreRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: _BoxScoreNameCell(
              player: player,
              stats: stats,
              leader: highlightName,
            ),
          ),
          for (final col in _boxScoreColumns)
            Expanded(
              flex: col.flex,
              child: Builder(
                builder: (context) {
                  final isLeader =
                      col.leaderValue != null &&
                      (leaders[col.label] ?? 0) > 0 &&
                      col.leaderValue!(stats) == leaders[col.label];
                  return Text(
                    col.value(stats),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isLeader ? FontWeight.w900 : FontWeight.w600,
                      color: isLeader
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

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
