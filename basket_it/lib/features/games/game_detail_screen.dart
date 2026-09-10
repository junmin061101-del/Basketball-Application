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

/// 경기 상세 화면: 스코어보드 + 오늘의 활약 + 양 팀 기록 비교 + 박스스코어.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boxScoreAsync = ref.watch(boxScoreProvider(game));
    final playersAsync = ref.watch(allPlayersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${game.date.month}월 ${game.date.day}일'),
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
    return Column(
      children: [
        if (game.status == GameStatus.live)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
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
                  'LIVE · ${game.liveClock ?? ''}',
                  style: const TextStyle(
                    color: AppColors.live,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else if (game.status == GameStatus.finished)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              '경기 종료',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              '경기 예정',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
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
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'VS',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w800,
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
                MaterialPageRoute(
                  builder: (_) => TeamDetailScreen(team: team),
                ),
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
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
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
    if (boxScore.isEmpty) return const SizedBox.shrink();

    final homeLines =
        boxScore.where((s) => s.teamId == homeTeam.id).toList()
          ..sort((a, b) => b.points.compareTo(a.points));
    final awayLines =
        boxScore.where((s) => s.teamId == awayTeam.id).toList()
          ..sort((a, b) => b.points.compareTo(a.points));

    final topLine = [...homeLines, ...awayLines].reduce(
      (a, b) => a.points >= b.points ? a : b,
    );
    final topPlayer = playerById[topLine.playerId];
    final topTeam = topLine.teamId == homeTeam.id ? homeTeam : awayTeam;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (topPlayer != null) ...[
          const _SectionTitle('오늘의 활약'),
          const SizedBox(height: 12),
          _TopPerformerCard(
            player: topPlayer,
            team: topTeam,
            stats: topLine,
          ),
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
        _SectionTitle(homeTeam.fullName),
        const SizedBox(height: 8),
        _BoxScoreTable(
          lines: homeLines,
          playerById: playerById,
        ),
        const SizedBox(height: 24),
        _SectionTitle(awayTeam.fullName),
        const SizedBox(height: 8),
        _BoxScoreTable(
          lines: awayLines,
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: team.primaryColor.withValues(alpha: 0.5)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              team.primaryColor.withValues(alpha: 0.22),
              AppColors.surface,
            ],
          ),
        ),
        child: Row(
          children: [
            TeamLogoPlaceholder(team: team, size: 52),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${team.fullName} · ${player.positionText}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
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
            Text(
              '${stats.points}',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                height: 1,
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
        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        children: [
          TextSpan(
            text: '$value ',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$homeScore',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '득점',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                '$awayScore',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          for (final row in rows) ...[
            _CompareRow(
              data: row,
              homeColor: homeTeam.primaryColor,
              awayColor: awayTeam.primaryColor,
            ),
            const SizedBox(height: 14),
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

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${data.homeValue}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(data.label, style: Theme.of(context).textTheme.bodySmall),
            Text(
              '${data.awayValue}',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Expanded(
                flex: (homeFraction * 1000).round().clamp(1, 999),
                child: Container(height: 6, color: homeColor),
              ),
              Expanded(
                flex: ((1 - homeFraction) * 1000).round().clamp(1, 999),
                child: Container(height: 6, color: awayColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 박스스코어 표에 표시할 스탯 컬럼 정의.
/// 이름 칸은 왼쪽에 고정되고, 이 컬럼들은 가로 스크롤 영역에 나란히 표시된다.
class _StatCol {
  final String label;
  final double width;
  final String Function(PlayerGameStats) value;
  final bool emphasize;

  const _StatCol(
    this.label,
    this.value, {
    this.width = 56,
    this.emphasize = false,
  });
}

String _pct(double ratio) => (ratio * 100).toStringAsFixed(1);

/// 머리글은 네이버 스포츠 박스스코어처럼 한국어로 적는다.
final _boxScoreColumns = <_StatCol>[
  _StatCol('출전', (s) => '${s.minutes}'),
  _StatCol('득점', (s) => '${s.points}', emphasize: true),
  _StatCol('리바운드', (s) => '${s.reb}', width: 74),
  _StatCol('어시스트', (s) => '${s.ast}', width: 74),
  _StatCol('스틸', (s) => '${s.stl}'),
  _StatCol('블록', (s) => '${s.blk}'),
  _StatCol('야투 성공', (s) => '${s.fgm}', width: 80),
  _StatCol('야투 시도', (s) => '${s.fga}', width: 80),
  _StatCol('야투율', (s) => _pct(s.fgPct), width: 66),
  _StatCol('3점 성공', (s) => '${s.tpm}', width: 76),
  _StatCol('3점 시도', (s) => '${s.tpa}', width: 76),
  _StatCol('3점슛률', (s) => _pct(s.tpPct), width: 72),
  _StatCol('자유투 성공', (s) => '${s.ftm}', width: 90),
  _StatCol('자유투 시도', (s) => '${s.fta}', width: 90),
  _StatCol('자유투율', (s) => _pct(s.ftPct), width: 74),
  _StatCol('공격 리바', (s) => '${s.oreb}', width: 80),
  _StatCol('수비 리바', (s) => '${s.dreb}', width: 80),
  _StatCol('턴오버', (s) => '${s.tov}', width: 66),
  _StatCol('파울', (s) => '${s.pf}'),
  _StatCol(
    '득실마진',
    (s) => s.plusMinus > 0 ? '+${s.plusMinus}' : '${s.plusMinus}',
    width: 74,
  ),
];

const _boxScoreNameColWidth = 96.0;
const _boxScoreRowHeight = 46.0;
const _boxScoreHeaderHeight = 34.0;

/// 선수 이름 칸은 고정하고 나머지 스탯은 가로로 스크롤하는 박스스코어 표.
class _BoxScoreTable extends StatelessWidget {
  final List<PlayerGameStats> lines;
  final Map<String, Player> playerById;

  const _BoxScoreTable({required this.lines, required this.playerById});

  @override
  Widget build(BuildContext context) {
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
            // 왼쪽 고정 칸: 선수 이름
            Container(
              width: _boxScoreNameColWidth,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Container(
                    height: _boxScoreHeaderHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '선수',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final line in lines)
                    _BoxScoreNameCell(
                      player: playerById[line.playerId],
                      stats: line,
                    ),
                ],
              ),
            ),
            // 오른쪽 스크롤 영역: MIN/PTS/REB/... 전체 스탯
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
                            _HeaderStatCell(col: col),
                        ],
                      ),
                    ),
                    for (final line in lines)
                      SizedBox(
                        height: _boxScoreRowHeight,
                        child: Row(
                          children: [
                            for (final col in _boxScoreColumns)
                              _ValueStatCell(col: col, stats: line),
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

class _HeaderStatCell extends StatelessWidget {
  final _StatCol col;

  const _HeaderStatCell({required this.col});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: col.width,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 10),
      child: Text(
        col.label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ValueStatCell extends StatelessWidget {
  final _StatCol col;
  final PlayerGameStats stats;

  const _ValueStatCell({required this.col, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: col.width,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        col.value(stats),
        style: col.emphasize
            ? const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              )
            : Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _BoxScoreNameCell extends StatelessWidget {
  final Player? player;
  final PlayerGameStats stats;

  const _BoxScoreNameCell({required this.player, required this.stats});

  @override
  Widget build(BuildContext context) {
    final name = player?.name ?? '알 수 없음';
    return InkWell(
      onTap: player == null
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PlayerDetailScreen(player: player!, gameStats: stats),
                ),
              );
            },
      child: Container(
        height: _boxScoreRowHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 12, right: 6),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
