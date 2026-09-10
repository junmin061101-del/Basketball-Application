import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/player_display.dart';
import '../../data/models/player.dart';
import '../../data/models/player_bio.dart';
import '../../data/models/player_game_stats.dart';
import '../../data/models/player_season_stats.dart';
import '../../data/models/team.dart';
import '../../providers/follow_actions.dart';
import '../../providers/onboarding_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/team_logo_placeholder.dart';

/// 선수 상세 화면.
///
/// 게임 탭/탐색 탭 어디서 진입하든 이 화면 하나를 공유한다. 신상 정보(키,
/// 몸무게, 생년월일, 출신 대학, 드래프트)와 시즌별 전체 스탯 표를 보여준다.
class PlayerDetailScreen extends ConsumerWidget {
  final Player player;
  final PlayerGameStats? gameStats;

  const PlayerDetailScreen({super.key, required this.player, this.gameStats});

  Team? _findTeam(List<Team>? teams) {
    if (teams == null) return null;
    final matches = teams.where((t) => t.id == player.teamId);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = _findTeam(ref.watch(teamsProvider).valueOrNull);
    final bioAsync = ref.watch(playerBioProvider(player));
    final seasonHistoryAsync = ref.watch(seasonStatsHistoryProvider(player));
    final followed = ref.watch(followedPlayerIdsProvider).contains(player.id);
    final accent = team?.primaryColor ?? AppColors.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _HeroHeader(player: player, team: team, accent: accent),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bioAsync.when(
                  loading: () => const _LoadingBlock(),
                  error: (err, _) => Text('불러오지 못했어요: $err'),
                  data: (bio) => _BioGrid(bio: bio),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => togglePlayerFollow(ref, player.id),
                    icon: Icon(
                      followed ? Icons.check : Icons.add,
                      size: 18,
                      color: followed ? Colors.white : accent,
                    ),
                    label: Text(followed ? '팔로잉' : '팔로우'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: followed ? accent : Colors.transparent,
                      foregroundColor: followed ? Colors.white : accent,
                      side: BorderSide(color: accent),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                if (gameStats != null) ...[
                  const SizedBox(height: 28),
                  Text(
                    '오늘 경기 기록',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _TodayStatsCard(stats: gameStats!),
                ],
                const SizedBox(height: 28),
                Text('이 시즌 평균', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                seasonHistoryAsync.when(
                  loading: () => const _LoadingBlock(),
                  error: (err, _) => Text('불러오지 못했어요: $err'),
                  data: (history) => _SeasonQuickCard(latest: history.first),
                ),
                const SizedBox(height: 28),
                Text('시즌별 기록', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '가로로 스크롤하면 전체 항목을 볼 수 있어요',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                seasonHistoryAsync.when(
                  loading: () => const _LoadingBlock(),
                  error: (err, _) => Text('불러오지 못했어요: $err'),
                  data: (history) => _SeasonStatsTable(
                    history: history,
                    // 시즌마다 그때 뛴 팀을 찾아 적는다. 현재 팀 하나를 모든
                    // 줄에 찍으면 르브론의 클리블랜드·마이애미 시절이 전부
                    // 지금 팀으로 나온다.
                    teamById: {
                      for (final t
                          in ref.watch(teamsProvider).valueOrNull ??
                              const <Team>[])
                        t.id: t,
                    },
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

class _HeroHeader extends StatelessWidget {
  final Player player;
  final Team? team;
  final Color accent;

  const _HeroHeader({
    required this.player,
    required this.team,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // 라이트 테마에서도 흰 글자 대비가 유지되도록 고정 다크 톤으로 페이드.
          colors: [accent.withValues(alpha: 0.9), AppColors.heroDark],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (team != null)
            Positioned(
              right: -20,
              top: 46,
              child: Opacity(
                opacity: 0.16,
                child: TeamLogoPlaceholder(team: team!, size: 168),
              ),
            ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (team != null)
                          Text(
                            team!.fullName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${player.positionText} · #${player.backNumber}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          player.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 30,
                            height: 1.05,
                          ),
                        ),
                        if (player.englishName != null &&
                            player.englishName != player.name) ...[
                          const SizedBox(height: 4),
                          Text(
                            player.englishName!,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _HeaderPhoto(player: player),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 헤더 오른쪽 선수 사진. 사진이 없으면 이름 글자로 대신한다.
class _HeaderPhoto extends StatelessWidget {
  final Player player;

  const _HeaderPhoto({required this.player});

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(
        playerInitial(player.name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
    const radius = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
    );
    final url = player.photoUrl;
    return Container(
      width: 92,
      height: 108,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: url == null
          ? initial
          : ClipRRect(
              borderRadius: radius,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (context, error, stackTrace) => initial,
              ),
            ),
    );
  }
}

class _BioGrid extends StatelessWidget {
  final PlayerBio bio;

  const _BioGrid({required this.bio});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rows = [
      (('키', bio.heightLabel), (bio.countryTitle, bio.countryLabel)),
      (
        ('생년월일', '${bio.birthLabel} (${bio.ageAt(now)}세)'),
        ('드래프트', bio.draftLabel),
      ),
      (('몸무게', '${bio.weightKg}kg'), ('출신 대학', bio.collegeLabel)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: _BioCell(label: rows[i].$1.$1, value: rows[i].$1.$2),
                ),
                const SizedBox(height: 52, child: VerticalDivider(width: 1)),
                Expanded(
                  child: _BioCell(label: rows[i].$2.$1, value: rows[i].$2.$2),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BioCell extends StatelessWidget {
  final String label;
  final String value;

  const _BioCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _SeasonQuickCard extends StatelessWidget {
  final PlayerSeasonStats latest;

  const _SeasonQuickCard({required this.latest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${latest.season} · ${latest.gamesPlayed}경기 출전',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Stat(label: '득점', value: latest.points.toStringAsFixed(1)),
              _Stat(label: '리바운드', value: latest.reb.toStringAsFixed(1)),
              _Stat(label: '어시스트', value: latest.ast.toStringAsFixed(1)),
              _Stat(label: '스틸', value: latest.stl.toStringAsFixed(1)),
              _Stat(label: '블록', value: latest.blk.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayStatsCard extends StatelessWidget {
  final PlayerGameStats stats;

  const _TodayStatsCard({required this.stats});

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
          _Stat(label: '득점', value: '${stats.points}'),
          _Stat(label: '리바운드', value: '${stats.reb}'),
          _Stat(label: '어시스트', value: '${stats.ast}'),
          _Stat(label: '스틸', value: '${stats.stl}'),
          _Stat(label: '블록', value: '${stats.blk}'),
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
              fontSize: 20,
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

/// 선수 상세 화면 필수 스펙(6단계)의 전 항목을 담은 시즌별 스탯 표.
/// 시즌(연도) 칸은 왼쪽에 고정하고, 나머지 항목은 가로로 스크롤한다.
class _SeasonCol {
  final String label;
  final double width;
  final String Function(PlayerSeasonStats, String teamLabel) value;
  final bool emphasize;

  const _SeasonCol(
    this.label,
    this.value, {
    this.width = 62,
    this.emphasize = false,
  });
}

String _pct(double ratio) => (ratio * 100).toStringAsFixed(1);
String _f1(double v) => v.toStringAsFixed(1);

/// 머리글은 네이버 스포츠 선수 기록표처럼 한국어로 적는다.
final _seasonColumns = <_SeasonCol>[
  _SeasonCol('경기', (s, _) => '${s.gamesPlayed}', width: 52),
  // 팀 표기는 표가 줄마다 계산해서 넘긴다(시즌별 소속팀, 여러 팀 합계 줄은 합계).
  _SeasonCol('팀', (_, teamLabel) => teamLabel, width: 108),
  _SeasonCol('출전시간', (s, _) => _f1(s.minutes), width: 74),
  _SeasonCol('득점', (s, _) => _f1(s.points), emphasize: true),
  _SeasonCol('야투 성공', (s, _) => _f1(s.fgm), width: 80),
  _SeasonCol('야투 시도', (s, _) => _f1(s.fga), width: 80),
  _SeasonCol('야투율', (s, _) => _pct(s.fgPct), width: 66),
  _SeasonCol('3점 성공', (s, _) => _f1(s.tpm), width: 76),
  _SeasonCol('3점 시도', (s, _) => _f1(s.tpa), width: 76),
  _SeasonCol('3점슛률', (s, _) => _pct(s.tpPct), width: 72),
  _SeasonCol('자유투 성공', (s, _) => _f1(s.ftm), width: 90),
  _SeasonCol('자유투 시도', (s, _) => _f1(s.fta), width: 90),
  _SeasonCol('자유투율', (s, _) => _pct(s.ftPct), width: 74),
  _SeasonCol('공격 리바', (s, _) => _f1(s.oreb), width: 80),
  _SeasonCol('수비 리바', (s, _) => _f1(s.dreb), width: 80),
  _SeasonCol('리바운드', (s, _) => _f1(s.reb), width: 74),
  _SeasonCol('어시스트', (s, _) => _f1(s.ast), width: 74),
  _SeasonCol('턴오버', (s, _) => _f1(s.tov), width: 66),
  _SeasonCol('스틸', (s, _) => _f1(s.stl)),
  _SeasonCol('블록', (s, _) => _f1(s.blk)),
  _SeasonCol('파울', (s, _) => _f1(s.pf)),
  // ESPN 시즌 평균에는 득실마진이 없어 0으로 온다. 0.0으로 적으면 실제 기록처럼 보인다.
  _SeasonCol(
    '득실마진',
    (s, _) => s.plusMinus == 0
        ? '-'
        : s.plusMinus > 0
        ? '+${_f1(s.plusMinus)}'
        : _f1(s.plusMinus),
    width: 74,
  ),
];

const _seasonColWidth = 76.0;
const _seasonRowHeight = 46.0;
const _seasonHeaderHeight = 34.0;

class _SeasonStatsTable extends StatelessWidget {
  final List<PlayerSeasonStats> history;
  final Map<String, Team> teamById;

  const _SeasonStatsTable({required this.history, required this.teamById});

  /// 한 줄의 팀 표기. 여러 팀 기록을 합친 줄은 합계.
  String _teamLabelOf(PlayerSeasonStats s) {
    if (s.isTotals) return '합계';
    return teamById[s.teamId]?.shortName ?? s.teamId.toUpperCase();
  }

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
            Container(
              width: _seasonColWidth,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  Container(
                    height: _seasonHeaderHeight,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      '시즌',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final s in history)
                    Container(
                      height: _seasonRowHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 12, right: 6),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Text(
                        s.season,
                        style: Theme.of(context).textTheme.titleMedium,
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
                      height: _seasonHeaderHeight,
                      child: Row(
                        children: [
                          for (final col in _seasonColumns)
                            Container(
                              width: col.width,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 10),
                              child: Text(
                                col.label,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final s in history)
                      SizedBox(
                        height: _seasonRowHeight,
                        child: Row(
                          children: [
                            for (final col in _seasonColumns)
                              Container(
                                width: col.width,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 10),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: AppColors.border),
                                  ),
                                ),
                                child: Text(
                                  col.value(s, _teamLabelOf(s)),
                                  style: col.emphasize
                                      ? const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        )
                                      : Theme.of(context).textTheme.bodyMedium,
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
