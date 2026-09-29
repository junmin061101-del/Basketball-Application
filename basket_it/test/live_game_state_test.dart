import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/data/models/league.dart';
import 'package:basket_it/data/models/live_game_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 정적 JSON은 20분에 한 번 올라온다. 경기 중 점수는 서버가 Firestore에
/// 적어 두는 값으로 덮어써야 제때 보인다.
void main() {
  final now = DateTime(2026, 9, 29, 21, 30);

  Map<String, dynamic> doc({
    int home = 55,
    int away = 61,
    String period = '3쿼터',
    String clock = '07:12',
    String status = 'live',
    Duration ago = const Duration(seconds: 20),
  }) => {
    'state': {
      'homeScore': home,
      'awayScore': away,
      'period': period,
      'clock': clock,
      'status': status,
    },
    'updatedAt': now.subtract(ago).millisecondsSinceEpoch,
  };

  final scheduled = Game(
    id: 'S49G14N6',
    date: DateTime(2026, 9, 29),
    homeTeamId: 'sk',
    awayTeamId: 'db',
    homeScore: 0,
    awayScore: 0,
    status: GameStatus.scheduled,
    startTime: DateTime(2026, 9, 29, 19),
  );

  Map<String, LiveGameState> states(Map<String, dynamic> data, {String key = 'kbl:S49G14N6'}) {
    final state = LiveGameState.fromDoc(key, data);
    return state == null ? {} : {key: state};
  }

  test('진행 중인 경기는 실시간 점수·쿼터·남은 시간으로 바뀐다', () {
    final game = applyLiveState(scheduled, states(doc()), League.kbl, now: now);

    expect(game.status, GameStatus.live);
    expect(game.homeScore, 55);
    expect(game.awayScore, 61);
    expect(game.liveClock, '3쿼터 07:12');
  });

  test('끝났다고 적힌 경기는 최종 점수로 바꾸고 시간은 지운다', () {
    final game = applyLiveState(
      scheduled,
      states(doc(status: 'final', period: '경기 종료', clock: '')),
      League.kbl,
      now: now,
    );

    expect(game.status, GameStatus.finished);
    expect(game.liveClock, isNull);
  });

  test('오래된 값은 쓰지 않는다(함수가 멈췄거나 종료를 못 적은 경우)', () {
    final game = applyLiveState(
      scheduled,
      states(doc(ago: const Duration(minutes: 30))),
      League.kbl,
      now: now,
    );

    expect(game.status, GameStatus.scheduled);
    expect(game.homeScore, 0);
  });

  test('수집기가 최종 결과를 올린 경기는 건드리지 않는다', () {
    final finished = Game(
      id: scheduled.id,
      date: scheduled.date,
      homeTeamId: 'sk',
      awayTeamId: 'db',
      homeScore: 85,
      awayScore: 103,
      status: GameStatus.finished,
      startTime: scheduled.startTime,
    );

    final game = applyLiveState(finished, states(doc()), League.kbl, now: now);

    expect(game.homeScore, 85);
    expect(game.awayScore, 103);
  });

  test('다른 리그 경기와 섞이지 않는다', () {
    final game = applyLiveState(
      scheduled,
      states(doc(), key: 'nba:S49G14N6'),
      League.kbl,
      now: now,
    );

    expect(game.status, GameStatus.scheduled);
  });

  test('모양이 다른 문서는 무시한다', () {
    expect(LiveGameState.fromDoc('kbl:1', {'state': 'nope'}), isNull);
    expect(LiveGameState.fromDoc('kbl:1', {'updatedAt': 1}), isNull);
  });
}
