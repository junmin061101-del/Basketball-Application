import 'package:basket_it/data/models/player_game_stats.dart';
import 'package:basket_it/features/games/game_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

PlayerGameStats line(
  String id, {
  int minutes = 20,
  int? seconds,
  bool? starter,
  int points = 10,
  int? plusMinus = 0,
}) => PlayerGameStats(
  playerId: id,
  gameId: 'g',
  teamId: 't',
  minutes: minutes,
  points: points,
  fgm: 0,
  fga: 0,
  tpm: 0,
  tpa: 0,
  ftm: 0,
  fta: 0,
  oreb: 0,
  dreb: 0,
  ast: 0,
  tov: 0,
  stl: 0,
  blk: 0,
  pf: 0,
  plusMinus: plusMinus,
  seconds: seconds,
  starter: starter,
);

void main() {
  test('출전 시간: 초를 알면 31:04, 분만 알면 22분(":00"을 지어 붙이지 않는다)', () {
    expect(line('a', seconds: 1864).playTimeLabel, '31:04');
    expect(line('a', seconds: 244).playTimeLabel, '4:04');
    expect(line('a', minutes: 22).playTimeLabel, '22분');
  });

  test('선발 / 후보로 나누고, 묶음 안은 출전 시간이 긴 순', () {
    final groups = groupBoxScore([
      line('bench-long', seconds: 1500, starter: false),
      line('starter-short', seconds: 1200, starter: true),
      line('starter-long', seconds: 2000, starter: true),
      line('bench-short', seconds: 300, starter: false),
    ]);
    expect(groups.map((g) => g.title), ['선발', '후보']);
    expect(groups[0].lines.map((l) => l.playerId), [
      'starter-long',
      'starter-short',
    ]);
    expect(groups[1].lines.map((l) => l.playerId), [
      'bench-long',
      'bench-short',
    ]);
  });

  test('선발 표시가 없는 예전 기록은 나누지 않는다', () {
    final groups = groupBoxScore([
      line('a', minutes: 10),
      line('b', minutes: 30),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.title, isNull);
    expect(groups.single.lines.map((l) => l.playerId), ['b', 'a']);
  });
}
