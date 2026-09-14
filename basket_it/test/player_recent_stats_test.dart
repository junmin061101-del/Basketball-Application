import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/data/models/player.dart';
import 'package:basket_it/data/models/player_game_stats.dart';
import 'package:basket_it/data/repositories/game_repository.dart';
import 'package:basket_it/providers/follow_feed_providers.dart';
import 'package:basket_it/providers/game_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 경기마다 정해 둔 박스스코어를 주고, 몇 경기를 물어봤는지 센다.
class _BoxScoreRepository implements GameRepository {
  final List<Game> games;
  final Set<String> playedIn;
  int boxScoreCalls = 0;

  _BoxScoreRepository(this.games, this.playedIn);

  @override
  Future<List<Game>> getGamesByDate(DateTime date) async => const [];

  @override
  Future<List<Game>> getGamesInRange(DateTime from, DateTime to) async => games;

  @override
  Future<List<PlayerGameStats>> getBoxScore(Game game) async {
    boxScoreCalls++;
    return [
      PlayerGameStats(
        playerId: playedIn.contains(game.id) ? 'kang' : 'other',
        gameId: game.id,
        teamId: 'db',
        minutes: 20,
        points: 10,
        fgm: 4,
        fga: 8,
        tpm: 0,
        tpa: 1,
        ftm: 2,
        fta: 2,
        oreb: 1,
        dreb: 3,
        ast: 2,
        tov: 1,
        stl: 0,
        blk: 0,
        pf: 2,
        plusMinus: 0,
      ),
    ];
  }
}

void main() {
  const player = Player(
    id: 'kang',
    name: '강상재',
    teamId: 'db',
    position: PlayerPosition.pf,
    backNumber: 26,
  );
  final now = DateTime.now();
  // 팀의 최근 30경기(가장 최근이 g0)
  final games = [
    for (var i = 0; i < 30; i++)
      Game(
        id: 'g$i',
        date: now.subtract(Duration(days: 2 * i + 1)),
        homeTeamId: 'db',
        awayTeamId: 'sk',
        homeScore: 80,
        awayScore: 70,
        status: GameStatus.finished,
        startTime: now.subtract(Duration(days: 2 * i + 1)),
      ),
  ];

  Future<List<String>> recentIds(_BoxScoreRepository repo) async {
    final container = ProviderContainer(
      overrides: [gameRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final rows = await container.read(playerRecentStatsProvider(player).future);
    return rows.map((r) => r.game.id).toList();
  }

  test('오래 결장한 선수도 마지막으로 뛴 경기들을 찾는다(팀의 22번째 경기부터)', () async {
    final repo = _BoxScoreRepository(games, {'g21', 'g22', 'g25'});
    expect(await recentIds(repo), ['g21', 'g22', 'g25']);
  });

  test('최신순으로 5경기만 보고, 다 찾으면 박스스코어를 더 받지 않는다', () async {
    final repo = _BoxScoreRepository(games, {
      for (var i = 0; i < 30; i++) 'g$i',
    });
    expect(await recentIds(repo), ['g0', 'g1', 'g2', 'g3', 'g4']);
    expect(repo.boxScoreCalls, 8); // 첫 묶음(8경기)에서 끝난다
  });
}
