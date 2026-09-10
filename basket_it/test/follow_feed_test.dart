import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/providers/follow_feed_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Game game({
  required String id,
  required String home,
  required String away,
  required int homeScore,
  required int awayScore,
  GameStatus status = GameStatus.finished,
}) {
  final start = DateTime(2026, 9, 1, 19);
  return Game(
    id: id,
    date: DateTime(2026, 9, 1),
    homeTeamId: home,
    awayTeamId: away,
    homeScore: homeScore,
    awayScore: awayScore,
    status: status,
    startTime: start,
  );
}

void main() {
  group('teamWon', () {
    test('홈으로 이기면 승', () {
      expect(teamWon(game(id: 'g', home: 'sk', away: 'lg', homeScore: 88, awayScore: 80), 'sk'), isTrue);
      expect(teamWon(game(id: 'g', home: 'sk', away: 'lg', homeScore: 88, awayScore: 80), 'lg'), isFalse);
    });

    test('원정으로 이기면 승', () {
      expect(teamWon(game(id: 'g', home: 'sk', away: 'lg', homeScore: 70, awayScore: 90), 'lg'), isTrue);
      expect(teamWon(game(id: 'g', home: 'sk', away: 'lg', homeScore: 70, awayScore: 90), 'sk'), isFalse);
    });
  });

  group('RecentForm', () {
    test('홈·원정을 가려 승패와 평균 득실점을 낸다', () {
      final games = [
        game(id: '1', home: 'sk', away: 'lg', homeScore: 90, awayScore: 80), // 승 90/80
        game(id: '2', home: 'db', away: 'sk', homeScore: 100, awayScore: 70), // 패 70/100
        game(id: '3', home: 'sk', away: 'kt', homeScore: 80, awayScore: 60), // 승 80/60
      ];
      final form = RecentForm.from(games, 'sk');

      expect(form.wins, 2);
      expect(form.losses, 1);
      expect(form.played, 3);
      expect(form.record, '2승 1패');
      expect(form.pointsFor, closeTo((90 + 70 + 80) / 3, 0.001));
      expect(form.pointsAgainst, closeTo((80 + 100 + 60) / 3, 0.001));
    });

    test('경기가 없으면 0으로 채우고 나누기를 하지 않는다', () {
      final form = RecentForm.from(const [], 'sk');
      expect(form.played, 0);
      expect(form.record, '0승 0패');
      expect(form.pointsFor, 0);
      expect(form.pointsAgainst, 0);
    });
  });
}
