import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/data/models/player_game_stats.dart';
import 'package:basket_it/providers/live_box_score_providers.dart';
import 'package:flutter_test/flutter_test.dart';

PlayerGameStats line(String id, int points) => PlayerGameStats.fromMap({
  'playerId': id,
  'teamId': 'sk',
  'name': '자밀 워니',
  'points': points,
  'seconds': 2214,
  'minutes': 37,
  'starter': true,
}, 'S49G01N7');

void main() {
  test('정적 JSON의 한 줄과 서버가 적은 한 줄을 같은 방법으로 읽는다', () {
    final stats = line('291248', 29);
    expect(stats.playerId, '291248');
    expect(stats.points, 29);
    expect(stats.playTimeLabel, '36:54');
    expect(stats.starter, isTrue);
    expect(stats.plusMinus, isNull); // 없으면 비워 둔다
  });

  test('진행 중인 경기는 지금 기록을, 끝난 경기는 수집기 기록을 쓴다', () {
    final stored = [line('a', 10)];
    final live = [line('b', 20)];

    // 경기 중: 수집기 기록은 20분 전 것이라 지금 기록이 먼저다.
    expect(
      chooseBoxScore(stored: stored, live: live, status: GameStatus.live).single.points,
      20,
    );
    // 끝난 뒤: 수집기가 올린 최종 기록을 쓴다.
    expect(
      chooseBoxScore(stored: stored, live: live, status: GameStatus.finished).single.points,
      10,
    );
    // 끝났는데 아직 안 올라왔으면(경기 직후) 서버가 적어 둔 것으로 메운다.
    expect(
      chooseBoxScore(stored: const [], live: live, status: GameStatus.finished).single.points,
      20,
    );
    // 둘 다 없으면 빈 목록.
    expect(
      chooseBoxScore(stored: const [], live: const [], status: GameStatus.live),
      isEmpty,
    );
  });
}
