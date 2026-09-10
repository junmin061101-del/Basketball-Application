import '../models/player.dart';
import '../models/player_bio.dart';
import '../models/player_season_stats.dart';

/// 선수 데이터 접근을 추상화한 Repository.
///
/// 리그마다 구현이 있다. NBA는 [NbaPlayerRepository], KBL은
/// [KblPlayerRepository]이고, 둘 다 수집기가 올려둔 실제 데이터를 읽는다.
/// 화면(Provider, UI)은 이 인터페이스만 안다.
abstract class PlayerRepository {
  Future<List<Player>> getPlayers();
  Future<Player?> getPlayerById(String id);
  Future<List<Player>> getPlayersByTeam(String teamId);

  /// 팔로워 수 기준 내림차순 정렬. 원본에 팔로워 수가 없는 리그는
  /// 이름순으로 준다.
  Future<List<Player>> getPlayersSortedByFollowers();

  /// 이름으로 선수를 검색한다.
  Future<List<Player>> searchPlayersByName(String query);

  /// 프로필 헤더에 쓰이는 신상 정보(키/몸무게/생년월일/드래프트 등).
  Future<PlayerBio> getPlayerBio(Player player);

  /// 시즌별 전체 스탯(최근 시즌이 0번 인덱스). 기록이 없으면 빈 목록.
  Future<List<PlayerSeasonStats>> getSeasonStatsHistory(Player player);

  /// 전체 선수의 이번 시즌 스탯. 랭킹 화면에서 부문별 순위를 낼 때 쓴다.
  Future<List<PlayerSeasonStats>> getCurrentSeasonStatsForAllPlayers();
}
