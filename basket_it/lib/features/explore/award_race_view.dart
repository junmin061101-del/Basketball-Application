import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/award_race.dart';
import '../../data/models/news_article.dart';
import '../../data/models/player.dart';
import '../../data/models/player_season_stats.dart';
import '../../data/models/team.dart';
import '../../providers/award_race_providers.dart';
import '../../providers/news_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/player_avatar.dart';
import '../player/player_detail_screen.dart';

const _upColor = Color(0xFF1F9D55);
const _downColor = Color(0xFFD64545);

/// 랭킹 - 수상 레이스: MVP / 올해의 수비수 / 신인왕.
///
/// 시즌 수상 결과(NBA 공식 발표)와 NBA.com 기자의 주간 사다리를 보여준다.
/// 사다리는 한 사람의 평가라 투표 결과처럼 보이지 않게 출처를 붙인다.
class AwardRaceView extends ConsumerStatefulWidget {
  const AwardRaceView({super.key});

  @override
  ConsumerState<AwardRaceView> createState() => _AwardRaceViewState();
}

class _AwardRaceViewState extends ConsumerState<AwardRaceView> {
  AwardType _type = AwardType.mvp;

  @override
  Widget build(BuildContext context) {
    final racesAsync = ref.watch(awardRacesProvider);
    final players = ref.watch(allPlayersProvider).valueOrNull ?? const [];
    final teams = ref.watch(teamsProvider).valueOrNull ?? const [];
    final stats =
        ref.watch(currentSeasonStatsAllProvider).valueOrNull ?? const [];

    return racesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$err', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref.invalidate(awardRacesProvider),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
      data: (races) {
        final race = races.raceOf(_type);
        final lookup = _Lookup(
          playerById: {for (final p in players) p.id: p},
          teamById: {for (final t in teams) t.id: t},
          statsById: {for (final s in stats) s.playerId: s},
          statsSeason: stats.isEmpty ? '' : stats.first.season,
        );
        return Column(
          children: [
            _AwardChips(
              selected: _type,
              onSelected: (type) => setState(() => _type = type),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  if (race.result != null) ...[
                    _ResultCard(result: race.result!, lookup: lookup),
                    const SizedBox(height: 24),
                  ],
                  if (race.ladder != null)
                    _LadderSection(
                      ladder: race.ladder!,
                      type: _type,
                      isFinal:
                          race.result?.season == race.ladder!.season &&
                          race.result?.winner != null,
                      lookup: lookup,
                    )
                  else
                    _NoLadder(type: _type, season: races.currentSeason),
                  const SizedBox(height: 20),
                  Text(
                    '사다리는 NBA.com 기자 한 명이 매주 매기는 순위로, 투표 결과가 '
                    '아니에요. 수상 결과는 NBA 공식 발표를 따릅니다.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 화면 곳곳에서 선수·팀·기록을 찾아 쓰기 위한 묶음.
class _Lookup {
  final Map<String, Player> playerById;
  final Map<String, Team> teamById;
  final Map<String, PlayerSeasonStats> statsById;
  final String statsSeason;

  const _Lookup({
    required this.playerById,
    required this.teamById,
    required this.statsById,
    required this.statsSeason,
  });

  Player? playerOf(AwardCandidate c) =>
      c.playerId == null ? null : playerById[c.playerId];

  /// 선수 목록에 없는 선수(은퇴 등)도 사진 없이 이름은 보여준다.
  Player avatarPlayerOf(AwardCandidate c) =>
      playerOf(c) ??
      Player(
        id: c.playerId ?? c.englishName,
        name: c.name,
        teamId: c.teamId ?? '',
        position: PlayerPosition.sf,
        backNumber: 0,
      );
}

class _AwardChips extends StatelessWidget {
  final AwardType selected;
  final ValueChanged<AwardType> onSelected;

  const _AwardChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        children: [
          for (final type in AwardType.values) ...[
            GestureDetector(
              onTap: () => onSelected(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: type == selected
                      ? AppColors.textPrimary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: type == selected
                        ? AppColors.textPrimary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  type.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: type == selected
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// 시즌 수상 결과: 수상자와 나머지 최종 후보.
class _ResultCard extends StatelessWidget {
  final AwardResult result;
  final _Lookup lookup;

  const _ResultCard({required this.result, required this.lookup});

  @override
  Widget build(BuildContext context) {
    final winner = result.winner;
    final others = [
      for (final f in result.finalists)
        if (!f.isWinner && f.englishName != winner?.englishName) f,
    ];
    final accent = winner?.teamId == null
        ? AppColors.primary
        : lookup.teamById[winner!.teamId]?.primaryColor ?? AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        // 반투명 팀 컬러에서 불투명한 바탕으로 곧장 그라데이션을 주면 중간이
        // 반쯤 불투명한 짙은 색으로 섞인다. 스퍼스처럼 검정 팀은 카드 가운데가
        // 회색 띠가 돼 흐린 글자가 안 읽힌다. 먼저 바탕에 섞어 불투명하게 만든다.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.12), AppColors.surface),
            AppColors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events_rounded, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(
                winner == null
                    ? '${result.season} 시즌 최종 후보 · 발표 전'
                    : '${result.season} 시즌 수상',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (winner != null) ...[
            const SizedBox(height: 14),
            _CandidateTile(candidate: winner, lookup: lookup, large: true),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              winner == null ? '최종 후보' : '다른 최종 후보',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            for (final f in others)
              _CandidateTile(candidate: f, lookup: lookup),
          ],
        ],
      ),
    );
  }
}

/// 최신 NBA.com 사다리.
class _LadderSection extends ConsumerWidget {
  final AwardLadder ladder;
  final AwardType type;

  /// 수상 발표가 난 시즌의 사다리인지. 그러면 "마지막 사다리"로 적는다.
  final bool isFinal;
  final _Lookup lookup;

  const _LadderSection({
    required this.ladder,
    required this.type,
    required this.isFinal,
    required this.lookup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ladder.publishedAt;
    final byline = [
      if (ladder.author != null) '${ladder.author}',
      '${date.month}월 ${date.day}일 발표',
      '${ladder.season} 시즌${isFinal ? ' 마지막 사다리' : ''}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NBA.com ${type.label} 사다리',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(byline, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        for (var i = 0; i < ladder.entries.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _LadderRow(
            entry: ladder.entries[i],
            type: type,
            ladderSeason: ladder.season,
            lookup: lookup,
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => ref.read(articleOpenerProvider)(
              context,
              NewsArticle(
                id: ladder.url,
                title: ladder.title,
                source: 'NBA.com',
                publishedAt: ladder.publishedAt,
                category: NewsCategory.nba,
                url: ladder.url,
              ),
            ),
            icon: const Icon(Icons.article_outlined, size: 18),
            label: const Text('NBA.com 원문 보기'),
          ),
        ),
      ],
    );
  }
}

class _LadderRow extends StatelessWidget {
  final AwardCandidate entry;
  final AwardType type;
  final String ladderSeason;
  final _Lookup lookup;

  const _LadderRow({
    required this.entry,
    required this.type,
    required this.ladderSeason,
    required this.lookup,
  });

  /// 사다리와 같은 시즌 기록이 있을 때만 한 줄 요약을 붙인다.
  String? _statLine() {
    if (entry.playerId == null || ladderSeason != lookup.statsSeason) {
      return null;
    }
    final s = lookup.statsById[entry.playerId];
    if (s == null) return null;
    String f(double v) => v.toStringAsFixed(1);
    return switch (type) {
      AwardType.dpoy => '블록 ${f(s.blk)} · 스틸 ${f(s.stl)} · 리바운드 ${f(s.reb)}',
      _ => '득점 ${f(s.points)} · 리바운드 ${f(s.reb)} · 어시스트 ${f(s.ast)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final player = lookup.playerOf(entry);
    final team = entry.teamId == null ? null : lookup.teamById[entry.teamId];
    final statLine = _statLine();

    return InkWell(
      onTap: player == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerDetailScreen(player: player),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Text(
                    '${entry.rank ?? '-'}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: (entry.rank ?? 99) <= 3
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  _MovementBadge(entry: entry),
                ],
              ),
            ),
            const SizedBox(width: 6),
            PlayerAvatar(player: lookup.avatarPlayerOf(entry), radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  // 팀과 기록을 한 줄에 이으면 "어시스/트"처럼 단어 중간에서 끊긴다.
                  if (team != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      team.fullName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (statLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      statLine,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 지난 사다리 대비 순위 변화.
class _MovementBadge extends StatelessWidget {
  final AwardCandidate entry;

  const _MovementBadge({required this.entry});

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;
    final previous = entry.previousRank;
    final diff = rank != null && previous != null ? (previous - rank).abs() : 0;
    final (text, color) = switch (entry.movement) {
      RankMovement.up => (diff > 0 ? '▲$diff' : '▲', _upColor),
      RankMovement.down => (diff > 0 ? '▼$diff' : '▼', _downColor),
      RankMovement.same => ('-', AppColors.textTertiary),
      RankMovement.newEntry => ('NEW', AppColors.primary),
      null => ('', AppColors.textTertiary),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final AwardCandidate candidate;
  final _Lookup lookup;
  final bool large;

  const _CandidateTile({
    required this.candidate,
    required this.lookup,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = lookup.playerOf(candidate);
    final team = candidate.teamId == null
        ? null
        : lookup.teamById[candidate.teamId];
    return InkWell(
      onTap: player == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PlayerDetailScreen(player: player),
              ),
            ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: large ? 2 : 6),
        child: Row(
          children: [
            PlayerAvatar(
              player: lookup.avatarPlayerOf(candidate),
              radius: large ? 28 : 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.name,
                    style: large
                        ? Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontSize: 21)
                        : Theme.of(context).textTheme.titleMedium,
                  ),
                  if (team != null)
                    Text(
                      team.fullName,
                      style: Theme.of(context).textTheme.bodySmall,
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

/// 이번·지난 시즌 사다리가 없을 때.
class _NoLadder extends StatelessWidget {
  final AwardType type;
  final String season;

  const _NoLadder({required this.type, required this.season});

  @override
  Widget build(BuildContext context) {
    final message = switch (type) {
      AwardType.dpoy =>
        'NBA.com은 2023년 이후 올해의 수비수 사다리를 따로 싣지 않고 있어요. '
            '새로 올라오면 자동으로 여기에 표시돼요.',
      _ =>
        '아직 $season 시즌 ${type.label} 사다리가 없어요. '
            '첫 사다리는 보통 개막 몇 주 뒤에 올라와요.',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
