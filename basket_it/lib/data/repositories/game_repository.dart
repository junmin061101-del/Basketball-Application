import '../models/game.dart';
import '../models/player_game_stats.dart';

/// 경기 데이터 접근을 추상화한 Repository.
///
/// 두 리그 모두 [CollectedGameRepository]가 수집기가 올려둔 실제 일정·결과·
/// 박스스코어를 읽는다. 화면(Provider, UI)은 이 인터페이스만 안다.
abstract class GameRepository {
  Future<List<Game>> getGamesByDate(DateTime date);
  Future<List<PlayerGameStats>> getBoxScore(Game game);

  /// [from]부터 [to]까지(양끝 포함)의 모든 경기를 날짜순으로 준다.
  ///
  /// 팀별 최근 전적, 다음 경기, 상대 전적처럼 하루치로는 답할 수 없는
  /// 화면에 쓴다.
  Future<List<Game>> getGamesInRange(DateTime from, DateTime to);
}
