import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/kbl_game_players.dart';
import 'game_54_0_rules.dart';
import 'models/game_54_0.dart';

/// 게임의 세 단계: 설명 → 다섯 라운드 → 결과.
enum GamePhase { intro, playing, finished }

/// 룰렛의 상태. 돌리는 건 사람이 누를 때다.
enum RouletteState {
  /// 아직 안 돌렸다. 구단·시대는 정해져 있지만 보여주지 않는다.
  ready,

  /// 도는 중.
  spinning,

  /// 멈췄다. 이제 선수 명단을 고른다.
  settled,
}

/// 총 라운드 수. 자리가 다섯이라 다섯 번 뽑는다.
const totalRounds = 5;

@immutable
class Game540State {
  final GamePhase phase;

  /// 1~5.
  final int round;

  /// 이번 라운드에 룰렛이 멈춘 조건. 결과 화면에서는 null이다.
  final RoundCondition? condition;

  /// 그 조건에서 고를 수 있는 선수들(이미 뽑은 선수는 빠진다).
  final List<GamePlayer> pool;

  /// 룰렛 상태. 사람이 누르면 돌고, 다 돌면 화면이 [Game540Controller.settle]을
  /// 불러 명단을 연다.
  final RouletteState roulette;

  /// 고른 선수. 자리에 넣기 전까지는 바꿀 수 있다.
  final GamePlayer? candidate;

  /// 자리에 들어간 선수. 한 번 넣으면 못 바꾼다.
  final Map<LineupSlot, GamePlayer> lineup;

  /// 조건 다시 뽑기는 한 게임에 한 번.
  final bool rerollUsed;

  /// 룰렛이 돌 때 스쳐 지나갈 수 있는 모든 조건.
  final List<RoundCondition> allConditions;

  final LineupResult? result;

  const Game540State({
    this.phase = GamePhase.intro,
    this.round = 1,
    this.condition,
    this.pool = const [],
    this.roulette = RouletteState.ready,
    this.candidate,
    this.lineup = const {},
    this.rerollUsed = false,
    this.allConditions = const [],
    this.result,
  });

  Game540State copyWith({
    GamePhase? phase,
    int? round,
    RoundCondition? condition,
    List<GamePlayer>? pool,
    RouletteState? roulette,
    GamePlayer? candidate,
    bool clearCandidate = false,
    Map<LineupSlot, GamePlayer>? lineup,
    bool? rerollUsed,
    LineupResult? result,
  }) => Game540State(
    phase: phase ?? this.phase,
    round: round ?? this.round,
    condition: condition ?? this.condition,
    pool: pool ?? this.pool,
    roulette: roulette ?? this.roulette,
    candidate: clearCandidate ? null : (candidate ?? this.candidate),
    lineup: lineup ?? this.lineup,
    rerollUsed: rerollUsed ?? this.rerollUsed,
    allConditions: allConditions,
    result: result ?? this.result,
  );

  /// 아직 비어 있는 자리.
  List<LineupSlot> get emptySlots =>
      LineupSlot.values.where((s) => !lineup.containsKey(s)).toList();
}

final game540Provider = AsyncNotifierProvider<Game540Controller, Game540State>(
  Game540Controller.new,
);

/// 54-0 게임 진행을 맡는다. 선수 명단을 한 번 읽어 두고 라운드를 굴린다.
class Game540Controller extends AsyncNotifier<Game540State> {
  final _repository = GamePlayerRepository();
  late RoundDraw _draw;
  WinDistribution? _distribution;
  Future<WinDistribution>? _distributionJob;

  /// 테스트에서 같은 순서가 나오도록 씨앗을 넣을 수 있다.
  @visibleForTesting
  static int? seed;

  @override
  Future<Game540State> build() async {
    final players = await _repository.load();
    final byCondition = groupByCondition(players);
    _draw = RoundDraw(
      byCondition: byCondition,
      random: seed == null ? Random() : Random(seed),
    );
    _warmUpRanking();
    return Game540State(allConditions: byCondition.keys.toList());
  }

  Game540State get _now => state.value ?? const Game540State();

  void start() {
    final drawn = _draw.drawCondition();
    if (drawn == null) return;
    state = AsyncData(
      Game540State(
        phase: GamePhase.playing,
        round: 1,
        condition: drawn.condition,
        pool: drawn.pool,
        allConditions: _now.allConditions,
      ),
    );
  }

  /// 사람이 룰렛을 돌린다. 구단·시대는 이때 공개된다.
  void spin() {
    final now = _now;
    if (now.phase != GamePhase.playing) return;
    if (now.roulette != RouletteState.ready) return;
    state = AsyncData(now.copyWith(roulette: RouletteState.spinning));
  }

  /// 룰렛이 멈췄다. 이제 선수 명단을 보여준다.
  void settle() {
    final now = _now;
    if (now.roulette != RouletteState.spinning) return;
    state = AsyncData(now.copyWith(roulette: RouletteState.settled));
  }

  /// 마음에 안 드는 조건을 한 번 바꾼다(구단·시대가 함께 바뀐다).
  void reroll() {
    final now = _now;
    if (now.phase != GamePhase.playing || now.rerollUsed) return;
    if (now.roulette != RouletteState.settled) return;
    final drawn = _draw.drawCondition(
      usedConditions: _usedConditions(now),
      usedPlayerIds: _placedIds(now),
    );
    if (drawn == null) return;
    state = AsyncData(
      now.copyWith(
        condition: drawn.condition,
        pool: drawn.pool,
        roulette: RouletteState.spinning,
        clearCandidate: true,
        rerollUsed: true,
      ),
    );
  }

  /// 명단에서 선수를 고른다. 자리에 넣기 전까지는 다시 고를 수 있다.
  void select(GamePlayer player) {
    final now = _now;
    if (now.phase != GamePhase.playing) return;
    if (now.roulette != RouletteState.settled) return;
    state = AsyncData(now.copyWith(candidate: player));
  }

  /// 고른 선수를 물린다.
  void unselect() {
    final now = _now;
    if (now.candidate == null) return;
    state = AsyncData(now.copyWith(clearCandidate: true));
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
          clearCandidate: true,
          result: _rank(simulate(lineup)),
        ),
      );
      return;
    }

    // 한 게임에 같은 구단이 두 번 나오지 않는다. 자리에 들어간 선수의 구단이
    // 곧 지나온 라운드다.
    final drawn = _draw.drawCondition(
      usedConditions: {
        for (final player in lineup.values)
          RoundCondition(teamId: player.teamId, teamName: player.teamName),
      },
      usedPlayerIds: {...lineup.values.map((p) => p.id)},
    );
    state = AsyncData(
      now.copyWith(
        round: now.round + 1,
        lineup: lineup,
        condition: drawn?.condition,
        pool: drawn?.pool ?? const [],
        roulette: RouletteState.ready,
        clearCandidate: true,
      ),
    );
  }

  /// 결과 화면에서 다시 도전한다. 다시 뽑기 기회도 되살아난다.
  void restart() {
    state = AsyncData(Game540State(allConditions: _now.allConditions));
    start();
  }

  /// 순위를 매길 기준(무작위 라인업 1,000팀)을 미리 만들어 둔다.
  ///
  /// 명단이 그대로라 분포도 그대로다. 한 번만 만들고 계속 쓴다.
  void _warmUpRanking() {
    _distributionJob ??=
        WinDistribution.sampleSpread(
          RoundDraw(byCondition: _draw.byCondition, random: Random(54)),
        ).then((distribution) {
          _distribution = distribution;
          return distribution;
        });
  }

  /// 무작위 라인업 1,000팀과 견줘 순위를 매긴다.
  LineupResult _rank(LineupResult result) {
    final ready = _distribution;
    if (ready != null) return _withRank(result, ready);
    // 아직 기준이 안 만들어졌으면, 다 되는 대로 결과에 순위만 얹는다.
    _distributionJob?.then((distribution) {
      final now = _now;
      if (now.phase != GamePhase.finished || now.result == null) return;
      state = AsyncData(
        now.copyWith(result: _withRank(now.result!, distribution)),
      );
    });
    return result;
  }

  LineupResult _withRank(LineupResult result, WinDistribution distribution) =>
      distribution.size == 0
      ? result
      : result.withRank(
          rank: distribution.rankOf(result.wins),
          rankPool: distribution.size,
        );

  /// 이미 지나온 구단(자리에 들어간 선수의 구단과 지금 조건).
  Set<RoundCondition> _usedConditions(Game540State now) => {
    for (final player in now.lineup.values)
      RoundCondition(teamId: player.teamId, teamName: player.teamName),
    if (now.condition != null) now.condition!,
  };

  Set<String> _placedIds(Game540State now) => {
    ...now.lineup.values.map((p) => p.id),
    if (now.candidate != null) now.candidate!.id,
  };
}
