import 'package:flutter/foundation.dart';

import 'game.dart';
import 'league.dart';

/// 진행 중인 경기의 지금 상태.
///
/// 서버(functions/live-score.js)가 30초마다 ESPN·KBL에서 확인해 Firestore의
/// `liveGames/{리그:경기id}`에 적어 둔다. 앱이 읽는 정적 JSON은 20분에 한 번만
/// 바뀌어서, 경기 중 점수·쿼터·남은 시간은 이 값으로 덮어써야 제때 보인다.
@immutable
class LiveGameState {
  /// "kbl:S49G14N6" 처럼 리그와 경기 id를 이은 키.
  final String key;
  final int homeScore;
  final int awayScore;

  /// "3쿼터", "하프타임", "경기 종료".
  final String period;

  /// 남은 시간 "07:12". 쿼터 사이나 종료 뒤에는 비어 있다.
  final String clock;

  /// 'live' 또는 'final'.
  final String status;

  /// 서버가 이 값을 적은 시각.
  final DateTime updatedAt;

  const LiveGameState({
    required this.key,
    required this.homeScore,
    required this.awayScore,
    required this.period,
    required this.clock,
    required this.status,
    required this.updatedAt,
  });

  /// Firestore 문서 한 건. 모양이 다르면 null.
  static LiveGameState? fromDoc(String key, Map<String, dynamic> data) {
    final state = data['state'];
    if (state is! Map) return null;
    final updated = data['updatedAt'];
    if (updated is! num) return null;
    int i(String k) => (state[k] as num?)?.toInt() ?? 0;
    return LiveGameState(
      key: key,
      homeScore: i('homeScore'),
      awayScore: i('awayScore'),
      period: state['period'] as String? ?? '',
      clock: state['clock'] as String? ?? '',
      status: state['status'] as String? ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updated.toInt()),
    );
  }

  bool get isLive => status == 'live';

  /// 끝난 경기인가. 최종 점수는 시간이 지나도 바뀌지 않는다.
  bool get isFinal => status == 'final';

  /// 서버가 한동안 갱신하지 못한 값인지. 함수가 멈춘 사이의 낡은 점수를
  /// 실시간인 척 보여주지 않기 위해 본다(진행 중인 경기에만 따진다).
  bool isStale([DateTime? now]) =>
      (now ?? DateTime.now()).difference(updatedAt) > const Duration(minutes: 10);

  /// "3쿼터 07:12". 둘 다 없으면 null.
  String? get clockLabel {
    final parts = [period, clock].where((p) => p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// 정적 JSON에서 읽은 [game]에 실시간 상태를 덮어쓴다.
///
/// 이미 끝난 경기(수집기가 최종 결과를 올린 뒤)는 그대로 둔다.
///
/// 진행 중인 상태는 10분만 믿는다. 반대로 끝난 경기의 최종 점수는 낡을 수가
/// 없어서 시간과 상관없이 쓴다. 정적 JSON을 올리는 수집기(GitHub Actions)는
/// 몇 시간씩 밀리는 일이 있어서, 이게 없으면 경기가 끝나고 한참 동안
/// "90-79 진행 중"이나 "0-0 예정"이 그대로 남는다.
Game applyLiveState(
  Game game,
  Map<String, LiveGameState> states,
  League league, {
  DateTime? now,
}) {
  final state = states['${league.wireName}:${game.id}'];
  if (state == null) return game;
  if (game.status == GameStatus.finished) return game;
  if (!state.isFinal && state.isStale(now)) return game;
  return Game(
    id: game.id,
    date: game.date,
    homeTeamId: game.homeTeamId,
    awayTeamId: game.awayTeamId,
    homeScore: state.homeScore,
    awayScore: state.awayScore,
    status: state.isLive ? GameStatus.live : GameStatus.finished,
    startTime: game.startTime,
    liveClock: state.isLive ? state.clockLabel : null,
  );
}
