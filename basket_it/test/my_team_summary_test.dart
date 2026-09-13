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

  test('순위와 바로 위·아래 팀과의 게임차', () {
    final s = MyTeamSummary.build(
      teamId: 'kgc',
      standings: kbl,
      games: const [],
      now: now,
    );
    expect(s.rank, 2);
    expect(s.rankLabel, '2위');
    expect((s.wins, s.losses), (35, 19));
    expect(
      (s.above!.teamId, s.above!.rank, s.above!.gamesBehind),
      ('lg', 1, 1.0),
    );
    expect(
      (s.below!.teamId, s.below!.rank, s.below!.gamesBehind),
      ('db', 3, 2.0),
    );

    final top = MyTeamSummary.build(
      teamId: 'lg',
      standings: kbl,
      games: const [],
      now: now,
    );
    expect(top.above, isNull);
    final last = MyTeamSummary.build(
      teamId: 'sk',
      standings: kbl,
      games: const [],
      now: now,
    );
    expect(last.below, isNull);
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
    expect(s.above!.teamId, '8');
    expect(s.above!.gamesBehind, 4);
    expect(s.below!.teamId, '18');
    expect(s.below!.gamesBehind, 3);
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
    expect(s.above, isNull);
  });

  test('최근 5경기(오래된 순)와 연승·연패', () {
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
    expect(s.lastFive, [false, true, false, false, false]);
    expect(s.streak, -3);
    expect(s.streakLabel, '3연패');

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

  test('오늘 경기가 있으면 그 경기, 없으면 가장 최근 경기를 크게 보여준다', () {
    final today = DateTime(2026, 4, 10);
    final games = [
      game('past', DateTime(2026, 4, 8, 19), 'kgc', 80, 'lg', 70),
      game(
        'today',
        today.add(const Duration(hours: 19)),
        'kgc',
        0,
        'db',
        0,
        status: GameStatus.scheduled,
      ),
      game(
        'next',
        DateTime(2026, 4, 12, 14),
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
    expect(s.featuredGame!.id, 'today');
    expect(s.featuredIsToday, isTrue);
    expect(s.nextGame!.id, 'next'); // 오늘 경기는 다음 경기로 또 보여주지 않는다

    final noToday = MyTeamSummary.build(
      teamId: 'kgc',
      standings: kbl,
      games: [games.first, games.last],
      now: today.add(const Duration(hours: 12)),
    );
    expect(noToday.featuredGame!.id, 'past');
    expect(noToday.featuredIsToday, isFalse);
    expect(noToday.nextGame!.id, 'next');
  });

  test('게임차 표기와 조사', () {
    expect(gamesBehindLabel(6), '6게임차');
    expect(gamesBehindLabel(0.5), '0.5게임차');
    expect(gamesBehindLabel(0), '승차 없음');
    expect(withWaGwa('NC'), 'NC와');
    expect(withWaGwa('LG'), 'LG와');
    expect(withWaGwa('KCC'), 'KCC와');
    expect(withWaGwa('정관장'), '정관장과');
    expect(withWaGwa('소노'), '소노와');
    expect(withWaGwa('삼성'), '삼성과');
    expect(withWaGwa('보스턴'), '보스턴과');
    expect(withWaGwa('디트로이트'), '디트로이트와');
  });
}
