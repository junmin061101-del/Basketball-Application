import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/data/models/team_standing.dart';
import 'package:basket_it/features/home/my_team_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Game game(
  String id,
  DateTime start,
  String home,
  int homeScore,
  String away,
  int awayScore, {
  GameStatus status = GameStatus.finished,
}) => Game(
  id: id,
  date: DateTime(start.year, start.month, start.day),
  homeTeamId: home,
  awayTeamId: away,
  homeScore: homeScore,
  awayScore: awayScore,
  status: status,
  startTime: start,
);

void main() {
  // KBL 2025-26 최종 순위 일부(수집 데이터와 같은 모양)
  const kbl = [
    TeamStanding(teamId: 'lg', wins: 36, losses: 18, gamesBehind: 0),
    TeamStanding(teamId: 'kgc', wins: 35, losses: 19, gamesBehind: 1),
    TeamStanding(teamId: 'db', wins: 33, losses: 21, gamesBehind: 3),
    TeamStanding(teamId: 'sk', wins: 32, losses: 22, gamesBehind: 4),
  ];
  final now = DateTime(2026, 4, 10, 12);

  test('순위와 앞뒤 순위표 다섯 줄', () {
    final s = MyTeamSummary.build(
      teamId: 'kgc',
      standings: kbl,
      games: const [],
      now: now,
    );
    expect(s.rank, 2);
    expect(s.rankLabel, '2위');
    expect((s.wins, s.losses), (35, 19));
    // 네 팀뿐이면 네 줄 다, 순위 그대로.
    expect(
      [for (final (r, t) in s.nearby) '$r${t.teamId}'],
      ['1lg', '2kgc', '3db', '4sk'],
    );

    final top = MyTeamSummary.build(
      teamId: 'lg',
      standings: kbl,
      games: const [],
      now: now,
    );
    expect(top.nearby.first.$1, 1);

    // 열 팀이면 내 팀을 가운데 두고, 끝에 붙으면 한쪽으로 민다.
    final ten = [
      for (var i = 0; i < 10; i++)
        TeamStanding(teamId: 't$i', wins: 20 - i, losses: i, gamesBehind: 0),
    ];
    List<int> ranks(String id) => [
      for (final (r, _) in MyTeamSummary.build(
        teamId: id,
        standings: ten,
        games: const [],
        now: now,
      ).nearby)
        r,
    ];
    expect(ranks('t4'), [3, 4, 5, 6, 7]);
    expect(ranks('t0'), [1, 2, 3, 4, 5]);
    expect(ranks('t9'), [6, 7, 8, 9, 10]);
  });

  test('NBA는 컨퍼런스 안 시드로 매기고 "동부 2위"로 쓴다', () {
    const nba = [
      TeamStanding(
        teamId: '13',
        wins: 50,
        losses: 32,
        gamesBehind: 0,
        conference: 'west',
        seed: 1,
      ),
      TeamStanding(
        teamId: '2',
        wins: 56,
        losses: 26,
        gamesBehind: 4,
        conference: 'east',
        seed: 2,
      ),
      TeamStanding(
        teamId: '8',
        wins: 60,
        losses: 22,
        gamesBehind: 0,
        conference: 'east',
        seed: 1,
      ),
      TeamStanding(
        teamId: '18',
        wins: 53,
        losses: 29,
        gamesBehind: 7,
        conference: 'east',
        seed: 3,
      ),
    ];
    final s = MyTeamSummary.build(
      teamId: '2',
      standings: nba,
      games: const [],
      now: now,
    );
    expect(s.rankLabel, '동부 2위');
    expect([for (final (_, t) in s.nearby) t.teamId], ['8', '2', '18']);
  });

  test('아무도 경기를 안 한 순위표(개막 전)는 순위를 내지 않는다', () {
    const empty = [
      TeamStanding(teamId: 'lg', wins: 0, losses: 0, gamesBehind: 0),
      TeamStanding(teamId: 'kgc', wins: 0, losses: 0, gamesBehind: 0),
    ];
    final s = MyTeamSummary.build(
      teamId: 'kgc',
      standings: empty,
      games: const [],
      now: now,
    );
    expect(s.rank, isNull);
    expect(s.rankLabel, isNull);
    expect(s.nearby, isEmpty);
  });

  test('일정은 끝난 경기로 다섯 칸을 채우고, 연승·연패를 센다', () {
    final games = [
      game('1', DateTime(2026, 3, 1, 19), 'kgc', 80, 'lg', 70), // 승
      game('2', DateTime(2026, 3, 3, 19), 'sk', 60, 'kgc', 75), // 승
      game('3', DateTime(2026, 3, 5, 19), 'kgc', 70, 'db', 71), // 패
      game('4', DateTime(2026, 3, 7, 19), 'kgc', 90, 'sk', 80), // 승
      game('5', DateTime(2026, 3, 9, 19), 'lg', 90, 'kgc', 80), // 패
      game('6', DateTime(2026, 3, 11, 19), 'db', 88, 'kgc', 77), // 패
      game('7', DateTime(2026, 3, 13, 19), 'kgc', 60, 'lg', 66), // 패
      game('x', DateTime(2026, 3, 14, 19), 'lg', 60, 'db', 66), // 다른 팀 경기
    ];
    final s = MyTeamSummary.build(
      teamId: 'kgc',
      standings: kbl,
      games: games,
      now: now,
    );
    expect([for (final g in s.schedule) g.id], ['3', '4', '5', '6', '7']);
    expect(s.streak, -3);
    expect(s.streakLabel, '3연패');
    expect(s.todayGame, isNull); // 오늘(4월 10일) 경기가 없다

    final one = MyTeamSummary.build(
      teamId: 'kgc',
      standings: kbl,
      games: games.take(4).toList(),
      now: now,
    );
    expect(one.streak, 1);
    expect(one.streakLabel, isNull); // 1경기는 연승으로 치지 않는다
  });

  test('연승·연패는 시즌을 건너 이어 세지 않는다', () {
    final games = [
      game('old', DateTime(2025, 4, 1, 19), 'kgc', 90, 'lg', 70), // 지난 시즌 승
      game('new1', DateTime(2025, 10, 20, 19), 'kgc', 91, 'lg', 70), // 새 시즌 승
      game('new2', DateTime(2025, 10, 22, 19), 'kgc', 92, 'lg', 70), // 승
    ];
    final s = MyTeamSummary.build(
      teamId: 'kgc',
      standings: kbl,
      games: games,
      now: DateTime(2025, 10, 23),
    );
    expect(s.streak, 2);
  });

  test('일정은 최근 경기 3개 뒤에 진행중·예정 경기 2개를 붙인다', () {
    final today = DateTime(2026, 4, 10);
    final games = [
      for (var d = 1; d <= 6; d++)
        game('p$d', DateTime(2026, 4, d, 19), 'kgc', 80, 'lg', 70),
      game(
        'live',
        today.add(const Duration(hours: 11)),
        'kgc',
        40,
        'db',
        38,
        status: GameStatus.live,
      ),
      for (var d = 12; d <= 16; d++)
        game(
          'n$d',
          DateTime(2026, 4, d, 19),
          'sk',
          0,
          'kgc',
          0,
          status: GameStatus.scheduled,
        ),
    ];
    final s = MyTeamSummary.build(
      teamId: 'kgc',
      standings: kbl,
      games: games,
      now: today.add(const Duration(hours: 12)),
    );
    expect(s.todayGame!.id, 'live');
    expect(
      [for (final g in s.schedule) g.id],
      ['p4', 'p5', 'p6', 'live', 'n12'],
    );
    // 끝난 경기가 1개뿐(개막 직후)이면 예정 경기로 채운다
    final early = MyTeamSummary.build(
      teamId: 'kgc',
      standings: kbl,
      games: games.skip(5).toList(),
      now: today.add(const Duration(hours: 12)),
    );
    expect(
      [for (final g in early.schedule) g.id],
      ['p6', 'live', 'n12', 'n13', 'n14'],
    );
  });
}
