import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/kbl_legend_players.dart';
import 'game_54_0_rules.dart';
import 'models/game_54_0.dart';

/// 게임의 세 단계: 설명 → 다섯 라운드 → 결과.
enum GamePhase { intro, playing, finished }

/// 총 라운드 수. 자리가 다섯이라 다섯 번 뽑는다.
const totalRounds = 5;

@immutable
class Game540State {
  final GamePhase phase;

  /// 1~5.
  final int round;

  /// 이번 라운드 조건과 등판한 선수. 결과 화면에서는 null이다.
  final RoundCondition? condition;
  final LegendPlayer? candidate;

  /// 자리에 들어간 선수. 한 번 넣으면 못 바꾼다.
  final Map<LineupSlot, LegendPlayer> lineup;

  /// 조건 다시 뽑기는 한 게임에 한 번.
  final bool rerollUsed;

  final LineupResult? result;

  const Game540State({
    this.phase = GamePhase.intro,
    this.round = 1,
    this.condition,
    this.candidate,
    this.lineup = const {},
    this.rerollUsed = false,
    this.result,
  });

  Game540State copyWith({
    GamePhase? phase,
    int? round,
    RoundCondition? condition,
    LegendPlayer? candidate,
    Map<LineupSlot, LegendPlayer>? lineup,
    bool? rerollUsed,
    LineupResult? result,
  }) => Game540State(
    phase: phase ?? this.phase,
    round: round ?? this.round,
    condition: condition ?? this.condition,
    candidate: candidate ?? this.candidate,
    lineup: lineup ?? this.lineup,
    rerollUsed: rerollUsed ?? this.rerollUsed,
    result: result ?? this.result,
  );

  /// 아직 비어 있는 자리.
  List<LineupSlot> get emptySlots =>
      LineupSlot.values.where((s) => !lineup.containsKey(s)).toList();
}

final game540Provider =
    AsyncNotifierProvider<Game540Controller, Game540State>(
      Game540Controller.new,
    );

/// 54-0 게임 진행을 맡는다. 선수 명단을 한 번 읽어 두고 라운드를 굴린다.
class Game540Controller extends AsyncNotifier<Game540State> {
  final _repository = LegendPlayerRepository();
  late RoundDraw _draw;

  /// 테스트에서 같은 순서가 나오도록 씨앗을 넣을 수 있다.
  @visibleForTesting
  static int? seed;

  @override
  Future<Game540State> build() async {
    final players = await _repository.load();
    _draw = RoundDraw(
      byCondition: groupByCondition(players),
      random: seed == null ? Random() : Random(seed),
    );
    return const Game540State();
  }

  Game540State get _now => state.value ?? const Game540State();

  void start() {
    final drawn = _draw.draw();
    if (drawn == null) return;
    state = AsyncData(
      Game540State(
        phase: GamePhase.playing,
        round: 1,
        condition: drawn.condition,
        candidate: drawn.player,
      ),
    );
  }

  /// 마음에 안 드는 조건을 한 번 바꾼다(구단·시대·선수가 함께 바뀐다).
  void reroll() {
    final now = _now;
    if (now.phase != GamePhase.playing || now.rerollUsed) return;
    final drawn = _draw.draw(
      usedConditions: {if (now.condition != null) now.condition!},
      usedPlayerIds: _placedIds(now),
    );
    if (drawn == null) return;
    state = AsyncData(
      now.copyWith(
        condition: drawn.condition,
        candidate: drawn.player,
        rerollUsed: true,
      ),
    );
  }

  /// 지금 선수를 [slot]에 넣는다. 다섯 자리가 차면 결과를 낸다.
  void place(LineupSlot slot) {
    final now = _now;
    final player = now.candidate;
    if (now.phase != GamePhase.playing || player == null) return;
    if (now.lineup.containsKey(slot)) return;

    final lineup = {...now.lineup, slot: player};
    if (lineup.length == totalRounds) {
      state = AsyncData(
        now.copyWith(
          phase: GamePhase.finished,
          lineup: lineup,
          result: simulate(lineup),
        ),
      );
      return;
    }

    final drawn = _draw.draw(usedPlayerIds: {...lineup.values.map((p) => p.id)});
    state = AsyncData(
      now.copyWith(
        round: now.round + 1,
        lineup: lineup,
        condition: drawn?.condition,
        candidate: drawn?.player,
      ),
    );
  }

  /// 결과 화면에서 다시 도전한다. 다시 뽑기 기회도 되살아난다.
  void restart() {
    state = const AsyncData(Game540State());
    start();
  }

  Set<String> _placedIds(Game540State now) => {
    ...now.lineup.values.map((p) => p.id),
    if (now.candidate != null) now.candidate!.id,
  };
}
