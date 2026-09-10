import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/features/home/widgets/followed_game_section.dart';
import 'package:flutter_test/flutter_test.dart';

Game g(String id, String home, String away, GameStatus status, int hour) => Game(
  id: id,
  date: DateTime(2026, 9, 10),
  homeTeamId: home,
  awayTeamId: away,
  homeScore: 80,
  awayScore: 75,
  status: status,
  startTime: DateTime(2026, 9, 10, hour),
);

void main() {
  final today = [
    g('fin', 'kt', 'sk', GameStatus.finished, 14),
    g('sched', 'lg', 'db', GameStatus.scheduled, 19),
    g('live', 'sk', 'kcc', GameStatus.live, 17),
    g('other', 'sono', 'mobis', GameStatus.live, 16), // 팔로우 안 한 팀끼리
  ];

  test('팔로우한 팀 경기만 남는다', () {
    final picked = FollowedGameSection.pickGames(today, {'sk'});
    expect(picked.map((e) => e.id), ['live', 'fin']);
  });

  test('진행중 > 예정 > 종료 순으로 정렬한다', () {
    final picked = FollowedGameSection.pickGames(today, {'sk', 'lg'});
    expect(picked.map((e) => e.id), ['live', 'sched', 'fin']);
  });

  test('같은 상태끼리는 시작이 이른 경기가 먼저', () {
    final games = [
      g('late', 'sk', 'a', GameStatus.scheduled, 20),
      g('early', 'sk', 'b', GameStatus.scheduled, 14),
    ];
    expect(
      FollowedGameSection.pickGames(games, {'sk'}).map((e) => e.id),
      ['early', 'late'],
    );
  });

  test('팔로우한 팀 경기가 없으면 빈 목록 (섹션이 숨겨진다)', () {
    expect(FollowedGameSection.pickGames(today, {'kogas'}), isEmpty);
    expect(FollowedGameSection.pickGames(today, const {}), isEmpty);
    expect(FollowedGameSection.pickGames(const [], {'sk'}), isEmpty);
  });

  test('원정으로 뛰는 경기도 내 팀 경기로 본다', () {
    final picked = FollowedGameSection.pickGames(today, {'kcc'});
    expect(picked.single.id, 'live');
  });
}
