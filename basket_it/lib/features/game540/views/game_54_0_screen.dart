import 'dart:async';
import 'dart:math';

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
          const PageHeader(title: '54 - 0'),
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
          '지금 KBL에서 뛰는 선수와 KBL 공식 기록으로 만듭니다.',
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
    ('1', '라운드마다 룰렛을 직접 돌려 KBL 10개 구단 중 하나를 뽑습니다.'),
    ('2', '그 구단 선수 명단에서 원하는 선수를 한 명 고릅니다.'),
    ('3', '고른 선수를 PG·SG·SF·PF·C 중 빈 자리에 넣습니다. 한 번 넣으면 못 바꿉니다.'),
    ('4', '마음에 안 드는 룰렛 결과는 게임당 한 번 다시 돌릴 수 있습니다.'),
    ('5', '다섯 자리가 차면 54경기 중 몇 승인지와 순위가 나옵니다.'),
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

/// 라운드 진행 화면: 룰렛 → 선수 고르기 → 자리 배치.
class _PlayView extends ConsumerWidget {
  final Game540State game;
  final Map<String, Team> teamById;

  const _PlayView({required this.game, required this.teamById});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(game540Provider.notifier);
    final condition = game.condition;
    if (condition == null) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            children: [
              _RoundBar(round: game.round),
              const SizedBox(height: 14),
              _Roulette(
                key: ValueKey('${game.round}:${condition.teamId}'),
                condition: condition,
                all: game.allConditions,
                teamById: teamById,
                roulette: game.roulette,
                onSpin: controller.spin,
                onSettled: controller.settle,
                rerollUsed: game.rerollUsed,
                onReroll: controller.reroll,
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (game.roulette) {
            RouletteState.ready => const _WaitingList(
              message: "'돌리기'를 눌러 구단과 시대를 뽑으세요",
            ),
            RouletteState.spinning => const _WaitingList(
              message: '어느 팀, 어느 시대가 걸릴까요?',
            ),
            RouletteState.settled =>
              game.candidate == null
                  ? _PlayerPicker(pool: game.pool, onPick: controller.select)
                  : _PlaceView(
                      player: game.candidate!,
                      lineup: game.lineup,
                      onPlace: controller.place,
                      onBack: controller.unselect,
                    ),
          },
        ),
      ],
    );
  }
}

/// 룰렛을 돌리기 전·도는 동안 명단 자리를 지켜 둔다. 멈추면 선수가 채워진다.
class _WaitingList extends StatelessWidget {
  final String message;

  const _WaitingList({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Center(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < 5; i++)
          Opacity(
            opacity: 1 - i * 0.16,
            child: Container(
              height: 58,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 86,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 58,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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

/// 구단·시대를 뽑는 룰렛.
///
/// 조건은 이미 정해져 있고, 이 위젯은 멈출 때까지 다른 조합을 스쳐 보여 준다.
/// 다 돌면 [onSettled]로 알려서 선수 명단이 열린다.
class _Roulette extends StatefulWidget {
  final RoundCondition condition;
  final List<RoundCondition> all;
  final Map<String, Team> teamById;
  final RouletteState roulette;
  final VoidCallback onSpin;
  final VoidCallback onSettled;
  final bool rerollUsed;
  final VoidCallback onReroll;

  const _Roulette({
    super.key,
    required this.condition,
    required this.all,
    required this.teamById,
    required this.roulette,
    required this.onSpin,
    required this.onSettled,
    required this.rerollUsed,
    required this.onReroll,
  });

  @override
  State<_Roulette> createState() => _RouletteState();
}

class _RouletteState extends State<_Roulette> {
  static const _ticks = 18;

  final _random = Random();
  Timer? _timer;
  late RoundCondition _shown = widget.condition;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    if (widget.roulette == RouletteState.spinning) _spin();
  }

  @override
  void didUpdateWidget(covariant _Roulette old) {
    super.didUpdateWidget(old);
    final spinning = widget.roulette == RouletteState.spinning;
    if (spinning && old.roulette != RouletteState.spinning) _spin();
    if (!spinning) _shown = widget.condition;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 처음엔 빠르게, 갈수록 느리게 돌다가 멈춘다.
  void _spin() {
    _tick = 0;
    _next(const Duration(milliseconds: 45));
  }

  void _next(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (!mounted) return;
      _tick++;
      if (_tick >= _ticks) {
        setState(() => _shown = widget.condition);
        widget.onSettled();
        return;
      }
      setState(() {
        _shown = widget.all.isEmpty
            ? widget.condition
            : widget.all[_random.nextInt(widget.all.length)];
      });
      _next(Duration(milliseconds: (delay.inMilliseconds * 1.12).round()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final spinning = widget.roulette == RouletteState.spinning;
    final ready = widget.roulette == RouletteState.ready;
    final team = widget.teamById[_shown.teamId];
    final teamName = ready ? '어느 구단?' : _shown.teamName;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: spinning ? AppColors.textPrimary : AppColors.surfaceCream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: ready
                  ? const _Mark(text: '?')
                  : (team == null
                        ? _Mark(text: _clubInitial(_shown.teamName))
                        : _TeamLogo(team: team, size: 40)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: spinning ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                ready
                    ? const Text(
                        '룰렛을 돌려 보세요',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      )
                    : Text(
                        spinning ? '뽑는 중' : '이 구단에서 한 명 고르세요',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: spinning
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textTertiary,
                        ),
                      ),
              ],
            ),
          ),
          if (ready)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: widget.onSpin,
                  style: ElevatedButton.styleFrom(
                    // 기본 버튼은 가로를 꽉 채우게 돼 있다(Size.fromHeight).
                    // 한 줄 안에 들어가야 해서 여기서만 폭을 줄인다.
                    minimumSize: const Size(78, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: const Text('돌리기'),
                ),
              ),
            )
          else if (spinning)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Text(
                '뽑는 중',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: widget.rerollUsed ? null : widget.onReroll,
              icon: const Icon(Icons.refresh, size: 17),
              label: Text(widget.rerollUsed ? '사용함' : '다시 돌리기'),
              style: TextButton.styleFrom(
                foregroundColor: widget.rerollUsed
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

/// 로고가 없을 때 쓰는 글자 한 자(로고를 지어내지 않는다).
class _Mark extends StatelessWidget {
  final String text;

  const _Mark({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// "원주 DB" → "D". 연고지를 뺀 구단 이름의 첫 글자.
String _clubInitial(String teamName) {
  final parts = teamName.split(' ');
  final club = parts.length > 1 ? parts.last : teamName;
  return club.isEmpty ? '?' : club.characters.first;
}

/// 뽑힌 구단·시대의 선수 명단. 검색·포지션·기록순으로 추려 고른다.
class _PlayerPicker extends StatefulWidget {
  final List<GamePlayer> pool;
  final ValueChanged<GamePlayer> onPick;

  const _PlayerPicker({required this.pool, required this.onPick});

  @override
  State<_PlayerPicker> createState() => _PlayerPickerState();
}

enum _SortKey {
  ppg('득점', '득점'),
  rpg('리바운드', '리바'),
  apg('어시스트', '어시'),
  spg('스틸', '스틸'),
  bpg('블락', '블락'),
  mpg('출전시간', '시간');

  final String label;

  /// 명단 칸처럼 좁은 자리에 쓰는 이름.
  final String short;

  const _SortKey(this.label, this.short);

  double of(GamePlayer p) => switch (this) {
    _SortKey.ppg => p.ppg,
    _SortKey.rpg => p.rpg,
    _SortKey.apg => p.apg,
    _SortKey.spg => p.spg,
    _SortKey.bpg => p.bpg,
    _SortKey.mpg => p.mpg,
  };
}

class _PlayerPickerState extends State<_PlayerPicker> {
  String _query = '';
  PlayerLine? _line;
  _SortKey _sort = _SortKey.ppg;

  @override
  Widget build(BuildContext context) {
    final rows =
        widget.pool
            .where((p) => _line == null || p.line == _line)
            .where((p) => _query.isEmpty || p.name.contains(_query))
            .toList()
          ..sort((a, b) => _sort.of(b).compareTo(_sort.of(a)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: SizedBox(
            height: 40,
            child: TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: '선수 이름 검색',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20),
                child: Row(
                  children: [
                    _filterChip('전체', null),
                    for (final line in PlayerLine.values)
                      _filterChip(line.korean, line),
                  ],
                ),
              ),
            ),
            PopupMenuButton<_SortKey>(
              initialValue: _sort,
              onSelected: (value) => setState(() => _sort = value),
              itemBuilder: (context) => [
                for (final key in _SortKey.values)
                  PopupMenuItem(value: key, child: Text('${key.label}순')),
              ],
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '${_sort.label}순',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: rows.isEmpty
              ? const Center(
                  child: Text(
                    '조건에 맞는 선수가 없어요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _PickerRow(
                    player: rows[i],
                    highlight: _sort,
                    onTap: () => widget.onPick(rows[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, PlayerLine? line) {
    final selected = _line == line;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: () => setState(() => _line = line),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 명단 한 줄: 선수와 그 시즌 경기당 기록.
class _PickerRow extends StatelessWidget {
  final GamePlayer player;
  final _SortKey highlight;
  final VoidCallback onTap;

  const _PickerRow({
    required this.player,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _PlayerFace(player: player, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${player.line.korean} · 평균 ${player.mpg.toStringAsFixed(1)}분',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                for (final key in const [
                  _SortKey.ppg,
                  _SortKey.rpg,
                  _SortKey.apg,
                  _SortKey.spg,
                  _SortKey.bpg,
                ])
                  _StatCell(
                    label: key.short,
                    value: key.of(player),
                    strong: key == highlight,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final double value;
  final bool strong;

  const _StatCell({
    required this.label,
    required this.value,
    required this.strong,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Column(
        children: [
          Text(
            value.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: strong ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              fontSize: 8.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 고른 선수를 어디에 세울지 정하는 화면.
class _PlaceView extends StatelessWidget {
  final GamePlayer player;
  final Map<LineupSlot, GamePlayer> lineup;
  final ValueChanged<LineupSlot> onPlace;
  final VoidCallback onBack;

  const _PlaceView({
    required this.player,
    required this.lineup,
    required this.onPlace,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        _CandidateCard(player: player),
        const SizedBox(height: 14),
        _Court(lineup: lineup, onTap: onPlace),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('다른 선수 고르기'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 이번에 등판한 선수.
class _CandidateCard extends StatelessWidget {
  final GamePlayer player;

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
                  '${player.line.korean} · ${player.season} ${player.games}경기',
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
  final Map<LineupSlot, GamePlayer> lineup;
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
  final GamePlayer? player;
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

/// 결과: 숫자가 굴러가며 승패와 순위, 라인업 기록이 드러난다.
class _ResultView extends ConsumerStatefulWidget {
  final Game540State game;
  final Map<String, Team> teamById;

  const _ResultView({required this.game, required this.teamById});

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  late final Animation<double> _roll = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final result = game.result;
    if (result == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _roll,
      builder: (context, _) {
        final t = _roll.value;
        final wins = (result.wins * t).round();
        final rolling = t < 1;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            _ResultHero(result: result, wins: wins, rolling: rolling),
            const SizedBox(height: 14),
            if (result.rankPool > 0) _RankCard(result: result, progress: t),
            if (result.rankPool > 0) const SizedBox(height: 14),
            _TeamStatCard(result: result, progress: t),
            const SizedBox(height: 18),
            Opacity(
              opacity: ((t - 0.7) / 0.3).clamp(0.0, 1.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        team: widget.teamById[game.lineup[slot]!.teamId],
                      ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: rolling
                              ? null
                              : () => _copyResult(context, game, result),
                          child: const Text('결과 복사'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: rolling
                              ? null
                              : () => ref
                                    .read(game540Provider.notifier)
                                    .restart(),
                          child: const Text('다시 도전'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 결과를 글로 만들어 클립보드에 넣는다(메신저에 그대로 붙여 넣을 수 있다).
  void _copyResult(
    BuildContext context,
    Game540State game,
    LineupResult result,
  ) {
    final percent = result.topPercent;
    final lines = [
      'Baskit 54 - 0 — ${result.headline}',
      if (percent != null)
        '라인업 ${result.rankPool}팀 중 ${result.rank}위 '
            '(상위 ${percent.toStringAsFixed(1)}%)',
      '',
      for (final slot in LineupSlot.values)
        if (game.lineup[slot] != null)
          '${slot.label}  ${game.lineup[slot]!.name} '
              '(${game.lineup[slot]!.teamName})',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('결과를 복사했어요')));
  }
}

/// 승패가 굴러가는 히어로 카드.
class _ResultHero extends StatelessWidget {
  final LineupResult result;
  final int wins;
  final bool rolling;

  const _ResultHero({
    required this.result,
    required this.wins,
    required this.rolling,
  });

  @override
  Widget build(BuildContext context) {
    final perfect = !rolling && result.isPerfect;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        color: perfect ? AppColors.primary : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            rolling ? '시즌을 치르는 중' : (result.isPerfect ? '완벽한 시즌' : '시즌 결과'),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$wins승 ${kbl54Games - wins}패',
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: wins / kbl54Games,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(
                perfect ? Colors.white : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '정규리그 $kbl54Games경기',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// 같은 규칙으로 만든 무작위 라인업과 견준 순위.
class _RankCard extends StatelessWidget {
  final LineupResult result;
  final double progress;

  const _RankCard({required this.result, required this.progress});

  @override
  Widget build(BuildContext context) {
    // 꼴찌에서 시작해 제 순위까지 올라온다.
    final rank = (result.rankPool - (result.rankPool - result.rank) * progress)
        .round();
    final percent = (rank / result.rankPool * 100).clamp(0.1, 100.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 21,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '순위',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$rank위 · 상위 ${percent.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '같은 규칙으로 만들어 본 라인업 ${result.rankPool}팀과 견줬어요.',
                  style: const TextStyle(
                    fontSize: 11,
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

/// 라인업 다섯 명의 경기당 기록 합계.
class _TeamStatCard extends StatelessWidget {
  final LineupResult result;
  final double progress;

  const _TeamStatCard({required this.result, required this.progress});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('평균 득점', result.ppg),
      ('평균 리바', result.rpg),
      ('평균 어시', result.apg),
      ('평균 스틸', result.spg),
      ('평균 블락', result.bpg),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '라인업 경기당 기록',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '다섯 명 합계',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (label, value) in rows)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        (value * progress).toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineupRow extends StatelessWidget {
  final LineupSlot slot;
  final GamePlayer player;
  final Team? team;

  const _LineupRow({
    required this.slot,
    required this.player,
    required this.team,
  });

  @override
  Widget build(BuildContext context) {
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
                  player.teamName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _StatCell(label: '득점', value: player.ppg, strong: true),
          _StatCell(label: '리바', value: player.rpg, strong: false),
          _StatCell(label: '어시', value: player.apg, strong: false),
        ],
      ),
    );
  }
}

/// 선수 얼굴. 사진이 없으면 이름 첫 글자로 대신한다.
///
/// 사진은 앱에 넣어 둔 것만 쓴다. KBL 서버에서 바로 불러오면 웹에서는 브라우저가
/// 직접 그리게 되는데, 목록을 넘길 때 앞 선수의 얼굴이 남아 이름과 어긋났다.
class _PlayerFace extends StatelessWidget {
  final GamePlayer player;
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
    final asset = player.photoAsset;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
      ),
      child: asset == null
          ? initial
          : ClipOval(
              child: Image.asset(
                asset,
                // 줄이 재사용돼도 다른 선수 사진이 남지 않도록 선수마다 따로 둔다.
                key: ValueKey(player.id),
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) =>
                    Center(child: initial),
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
