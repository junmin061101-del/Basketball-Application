import '../mock/mock_kbl_data.dart';
import '../models/game.dart';
import '../models/player_game_stats.dart';
import '../../core/utils/stable_hash.dart';
import '../../core/utils/stable_random.dart';

/// 경기 데이터 접근을 추상화한 Repository.
///
/// 지금은 [MockGameRepository]가 날짜를 기준으로 결정론적인(같은 날짜는
/// 항상 같은 결과) 목업 경기/박스스코어를 생성한다. 실제 API가 준비되면
/// 이 인터페이스를 구현하는 `ApiGameRepository` 하나로 교체하면 된다.
abstract class GameRepository {
  Future<List<Game>> getGamesByDate(DateTime date);
  Future<List<PlayerGameStats>> getBoxScore(Game game);

  /// [from]부터 [to]까지(양끝 포함) 하루씩 훑어 모든 경기를 날짜순으로 준다.
  ///
  /// 팀별 최근 전적, 다음 경기, 상대 전적처럼 하루치로는 답할 수 없는
  /// 화면에 쓴다.
  Future<List<Game>> getGamesInRange(DateTime from, DateTime to);
}

class MockGameRepository implements GameRepository {
  @override
  Future<List<Game>> getGamesByDate(DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 350));
    return _gamesFor(_dateOnly(date));
  }

  @override
  Future<List<Game>> getGamesInRange(DateTime from, DateTime to) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final start = _dateOnly(from);
    final end = _dateOnly(to);
    if (end.isBefore(start)) return const [];

    final games = <Game>[];
    for (
      var day = start;
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))
    ) {
      games.addAll(_gamesFor(day));
    }
    games.sort((a, b) => a.startTime.compareTo(b.startTime));
    return games;
  }

  @override
  Future<List<PlayerGameStats>> getBoxScore(Game game) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (game.status == GameStatus.scheduled) return const [];
    return _boxScoreFor(
      game.id,
      game.homeTeamId,
      game.awayTeamId,
      game.status == GameStatus.live,
    );
  }

  // ---- 내부 생성 로직 (같은 입력이면 항상 같은 결과) ----

  static final _teamIds = kMockTeams.map((t) => t.id).toList();
  static final _today = _dateOnly(DateTime.now());

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Game> _gamesFor(DateTime date) {
    final dayIndex = date.difference(DateTime(2000, 1, 1)).inDays;
    // KBL은 평일 1경기, 주말(금~일)엔 2경기가 열리는 경우가 많다는 걸 반영.
    final numGames = date.weekday >= DateTime.friday ? 2 : 1;

    // 같은 날 한 팀이 두 경기를 뛰지 않도록, 하루치 대진을 한 번의 셔플로 뽑는다.
    final dayShuffle = [..._teamIds]..shuffle(StableRandom(dayIndex));

    return List.generate(numGames, (i) {
      final homeTeamId = dayShuffle[i * 2];
      final awayTeamId = dayShuffle[i * 2 + 1];
      final gameId =
          '${date.year}${_pad(date.month)}${_pad(date.day)}-$homeTeamId-$awayTeamId';

      final GameStatus status;
      if (date.isBefore(_today)) {
        status = GameStatus.finished;
      } else if (date.isAfter(_today)) {
        status = GameStatus.scheduled;
      } else {
        status = i == 0 ? GameStatus.live : GameStatus.scheduled;
      }

      final boxScore = status == GameStatus.scheduled
          ? const <PlayerGameStats>[]
          : _boxScoreFor(
              gameId,
              homeTeamId,
              awayTeamId,
              status == GameStatus.live,
            );

      final homeScore = _teamPoints(boxScore, homeTeamId);
      final awayScore = _teamPoints(boxScore, awayTeamId);

      // 평일 19:00(2경기면 19:30), 주말 14:00 / 16:00 팁오프.
      final isWeekend = date.weekday >= DateTime.saturday;
      final startTime = isWeekend
          ? DateTime(date.year, date.month, date.day, 14 + i * 2)
          : DateTime(date.year, date.month, date.day, 19, i * 30);

      return Game(
        id: gameId,
        date: date,
        homeTeamId: homeTeamId,
        awayTeamId: awayTeamId,
        homeScore: homeScore,
        awayScore: awayScore,
        status: status,
        startTime: startTime,
        liveClock: status == GameStatus.live
            ? _liveClock(dayIndex + i)
            : null,
      );
    });
  }

  int _teamPoints(List<PlayerGameStats> boxScore, String teamId) =>
      boxScore
          .where((s) => s.teamId == teamId)
          .fold(0, (sum, s) => sum + s.points);

  String _liveClock(int seed) {
    final rng = StableRandom(seed);
    final quarter = 1 + (seed % 4);
    final minute = rng.nextInt(10);
    final second = rng.nextInt(60);
    return '$quarter쿼터 ${_pad(minute)}:${_pad(second)}';
  }

  /// gameId만으로 결정되는 박스스코어. 같은 경기는 목록/상세 어디서 호출해도
  /// 항상 같은 값을 반환한다. [live]면 아직 경기 중이라 스탯을 진행률만큼
  /// (대략 3쿼터 소화 기준) 축소해서 보여준다.
  List<PlayerGameStats> _boxScoreFor(
    String gameId,
    String homeTeamId,
    String awayTeamId,
    bool live,
  ) {
    final progress = live ? 0.72 : 1.0;

    final lines = <PlayerGameStats>[];
    for (final teamId in [homeTeamId, awayTeamId]) {
      final roster = kMockPlayers.where((p) => p.teamId == teamId).toList();
      for (var idx = 0; idx < roster.length; idx++) {
        lines.add(
          _playerLine(
            gameId: gameId,
            teamId: teamId,
            playerId: roster[idx].id,
            // 로스터 앞쪽(주전 취급)일수록 출전 비중이 높다.
            usageBoost: idx < 2 ? 2 : (idx < 4 ? 1 : 0),
            progress: progress,
          ),
        );
      }
    }
    return lines;
  }

  PlayerGameStats _playerLine({
    required String gameId,
    required String teamId,
    required String playerId,
    required int usageBoost,
    required double progress,
  }) {
    final rng = StableRandom(stableSeed([gameId, playerId]));

    final minutes = ((6 + rng.nextInt(24) + usageBoost * 4) * progress)
        .round()
        .clamp(0, 40);
    final fga = ((minutes * (0.35 + rng.nextDouble() * 0.25)))
        .round()
        .clamp(0, 30);
    final fgm = (fga * (0.35 + rng.nextDouble() * 0.25)).round().clamp(
      0,
      fga,
    );
    final tpa = (fga * rng.nextDouble() * 0.45).round().clamp(0, fga);
    var tpm = (tpa * (0.25 + rng.nextDouble() * 0.3)).round().clamp(0, tpa);
    if (tpm > fgm) tpm = fgm;
    final fta = rng.nextInt(7);
    final ftm = (fta * (0.6 + rng.nextDouble() * 0.35)).round().clamp(0, fta);
    final points = 2 * fgm + tpm + ftm;

    return PlayerGameStats(
      playerId: playerId,
      gameId: gameId,
      teamId: teamId,
      minutes: minutes,
      points: points,
      fgm: fgm,
      fga: fga,
      tpm: tpm,
      tpa: tpa,
      ftm: ftm,
      fta: fta,
      oreb: rng.nextInt(4),
      dreb: rng.nextInt(7),
      ast: rng.nextInt(8),
      tov: rng.nextInt(4),
      stl: rng.nextInt(3),
      blk: rng.nextInt(3),
      pf: rng.nextInt(5),
      plusMinus: rng.nextInt(25) - 12,
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
