import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/team.dart';
import '../../../providers/repository_providers.dart';
import '../../common/page_header.dart';
import '../game_54_0_controller.dart';
import '../game_54_0_rules.dart';
import '../models/game_54_0.dart';

/// 미니게임 "54-0": 다섯 라운드 동안 뽑힌 선수로 전승 라인업을 만든다.
class Game540Screen extends ConsumerWidget {
  const Game540Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(game540Provider);
    final teams = ref.watch(teamsProvider).valueOrNull ?? const <Team>[];
    final teamById = {for (final t in teams) t.id: t};

    return Scaffold(
      body: Column(
        children: [
          const PageHeader(title: '54-0'),
          Expanded(
            child: gameAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    '선수 명단을 불러오지 못했어요.\n$err',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              data: (game) => switch (game.phase) {
                GamePhase.intro => _IntroView(
                  onStart: () => ref.read(game540Provider.notifier).start(),
                ),
                GamePhase.playing => _PlayView(game: game, teamById: teamById),
                GamePhase.finished => _ResultView(
                  game: game,
                  teamById: teamById,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 규칙을 알려주고 시작 버튼을 보여주는 첫 화면.
class _IntroView extends StatelessWidget {
  final VoidCallback onStart;

  const _IntroView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'KBL 미니게임',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '54 - 0',
                style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '정규리그 54경기, 전승 라인업을 만들어 보세요.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _RuleCard(),
        const SizedBox(height: 18),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: onStart,
            child: const Text(
              '54-0 도전하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '선수와 기록은 모두 KBL 공식 기록(1997년 원년부터)입니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard();

  static const _rules = [
    ('1', '라운드마다 구단과 시대가 무작위로 정해지고, 그 시절 그 팀에서 뛴 선수 한 명이 나옵니다.'),
    ('2', '나온 선수를 PG·SG·SF·PF·C 중 빈 자리에 넣습니다. 한 번 넣으면 못 바꿉니다.'),
    ('3', '마음에 안 드는 조건은 게임당 한 번 다시 뽑을 수 있습니다.'),
    ('4', '다섯 자리가 차면 전력·자리 적합·호흡을 따져 54경기 중 몇 승인지 계산합니다.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '게임 방법',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          for (final (number, text) in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      number,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textSecondary,
                      ),
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

/// 라운드 진행 화면: 조건 카드 → 선수 카드 → 코트.
class _PlayView extends ConsumerWidget {
  final Game540State game;
  final Map<String, Team> teamById;

  const _PlayView({required this.game, required this.teamById});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(game540Provider.notifier);
    final condition = game.condition;
    final candidate = game.candidate;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        _RoundBar(round: game.round),
        const SizedBox(height: 16),
        if (condition != null && candidate != null) ...[
          _ConditionCard(
            condition: condition,
            team: teamById[condition.teamId],
            rerollUsed: game.rerollUsed,
            onReroll: controller.reroll,
          ),
          const SizedBox(height: 12),
          _CandidateCard(player: candidate),
        ],
        const SizedBox(height: 20),
        const Text(
          '어느 자리에 세울까요?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        _Court(lineup: game.lineup, onTap: controller.place),
      ],
    );
  }
}

class _RoundBar extends StatelessWidget {
  final int round;

  const _RoundBar({required this.round});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Round $round',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          '/ $totalRounds',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
          ),
        ),
        const Spacer(),
        for (var i = 1; i <= totalRounds; i++)
          Container(
            width: i == round ? 18 : 7,
            height: 7,
            margin: const EdgeInsets.only(left: 5),
            decoration: BoxDecoration(
              color: i <= round ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// 이번 라운드 조건: 구단 로고·이름 + 시대 뱃지.
class _ConditionCard extends StatelessWidget {
  final RoundCondition condition;
  final Team? team;
  final bool rerollUsed;
  final VoidCallback onReroll;

  const _ConditionCard({
    required this.condition,
    required this.team,
    required this.rerollUsed,
    required this.onReroll,
  });

  @override
  Widget build(BuildContext context) {
    final teamName = team == null
        ? condition.teamId.toUpperCase()
        : '${team!.city} ${team!.name}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          if (team != null) _TeamLogo(team: team!, size: 40),
          if (team != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    condition.eraLabel,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: rerollUsed ? null : onReroll,
            icon: const Icon(Icons.refresh, size: 17),
            label: Text(rerollUsed ? '사용함' : '다시 뽑기'),
            style: TextButton.styleFrom(
              foregroundColor: rerollUsed
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 이번에 등판한 선수.
class _CandidateCard extends StatelessWidget {
  final LegendPlayer player;

  const _CandidateCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _PlayerFace(player: player, size: 62),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${player.line.korean} · ${player.season} ${player.teamName}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  player.statLine,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
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

/// 다섯 자리를 코트 모양으로 늘어놓는다. 빈 자리를 누르면 지금 선수가 들어간다.
class _Court extends StatelessWidget {
  final Map<LineupSlot, LegendPlayer> lineup;
  final ValueChanged<LineupSlot> onTap;

  const _Court({required this.lineup, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // 골대 쪽: 파워포워드 · 센터 · 스몰포워드
          Row(
            children: [
              Expanded(child: _slot(LineupSlot.pf)),
              const SizedBox(width: 10),
              Expanded(child: _slot(LineupSlot.c)),
              const SizedBox(width: 10),
              Expanded(child: _slot(LineupSlot.sf)),
            ],
          ),
          const SizedBox(height: 12),
          // 외곽: 포인트가드 · 슈팅가드
          Row(
            children: [
              const Spacer(),
              Expanded(flex: 3, child: _slot(LineupSlot.pg)),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: _slot(LineupSlot.sg)),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slot(LineupSlot slot) =>
      _SlotTile(slot: slot, player: lineup[slot], onTap: () => onTap(slot));
}

class _SlotTile extends StatelessWidget {
  final LineupSlot slot;
  final LegendPlayer? player;
  final VoidCallback onTap;

  const _SlotTile({
    required this.slot,
    required this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = player != null;
    return InkWell(
      onTap: filled ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 116,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.border,
            width: filled ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (filled) ...[
              _PlayerFace(player: player!, size: 40),
              const SizedBox(height: 7),
              Text(
                player!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                slot.label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ] else ...[
              const Icon(Icons.add, size: 20, color: AppColors.textTertiary),
              const SizedBox(height: 8),
              Text(
                slot.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                slot.korean,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 결과: 승수, 근거, 완성된 라인업.
class _ResultView extends ConsumerWidget {
  final Game540State game;
  final Map<String, Team> teamById;

  const _ResultView({required this.game, required this.teamById});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = game.result;
    if (result == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: BoxDecoration(
            color: result.isPerfect ? AppColors.primary : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                result.isPerfect ? '완벽한 시즌' : '시즌 결과',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '54경기 중 ${result.wins}승',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ScoreBars(result: result),
        const SizedBox(height: 18),
        const Text(
          '내 라인업',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final slot in LineupSlot.values)
          if (game.lineup[slot] != null)
            _LineupRow(
              slot: slot,
              player: game.lineup[slot]!,
              team: teamById[game.lineup[slot]!.teamId],
            ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _copyResult(context, game, result),
                child: const Text('결과 복사'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => ref.read(game540Provider.notifier).restart(),
                child: const Text('다시 도전'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 결과를 글로 만들어 클립보드에 넣는다(메신저에 그대로 붙여 넣을 수 있다).
  void _copyResult(
    BuildContext context,
    Game540State game,
    LineupResult result,
  ) {
    final lines = [
      'Baskit 54-0 — ${result.headline}',
      for (final slot in LineupSlot.values)
        if (game.lineup[slot] != null)
          '${slot.label}  ${game.lineup[slot]!.name} '
              '(${game.lineup[slot]!.season} ${game.lineup[slot]!.teamName})',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('결과를 복사했어요')));
  }
}

class _ScoreBars extends StatelessWidget {
  final LineupResult result;

  const _ScoreBars({required this.result});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('전력', result.powerScore, '선수들의 경기당 기록'),
      ('자리 적합', result.fitScore, '제 포지션에 섰는지'),
      ('호흡', result.synergyScore, '같은 팀·같은 시대를 함께한 조합'),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final (label, score, hint) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        score.round().toString(),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textTertiary,
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

class _LineupRow extends StatelessWidget {
  final LineupSlot slot;
  final LegendPlayer player;
  final Team? team;

  const _LineupRow({
    required this.slot,
    required this.player,
    required this.team,
  });

  @override
  Widget build(BuildContext context) {
    final fit = slotFit(player.line, slot);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              slot.label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _PlayerFace(player: player, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${player.season} ${player.teamName} · ${player.statLine}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            fit >= 1 ? '제자리' : '적합 ${(fit * 100).round()}%',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: fit >= 1 ? AppColors.positive : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 선수 얼굴. 사진이 없으면 이름 첫 글자로 대신한다.
class _PlayerFace extends StatelessWidget {
  final LegendPlayer player;
  final double size;

  const _PlayerFace({required this.player, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial = Text(
      player.name.isEmpty ? '?' : player.name.characters.first,
      style: TextStyle(
        fontSize: size * 0.4,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
      ),
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.network(
          player.photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
          errorBuilder: (context, error, stackTrace) => Center(child: initial),
        ),
      ),
    );
  }
}

/// 팀 로고. 앱에 넣어 둔 KBL 공식 아이콘을 쓴다.
class _TeamLogo extends StatelessWidget {
  final Team team;
  final double size;

  const _TeamLogo({required this.team, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = team.logoAsset;
    if (asset == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            team.name.characters.first,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      );
    }
    return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
  }
}
