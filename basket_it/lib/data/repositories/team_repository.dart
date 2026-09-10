import '../models/team.dart';
import '../models/team_season_stats.dart';
import '../models/team_standing.dart';

/// 팀 데이터 접근을 추상화한 Repository.
///
/// 두 리그 모두 [CollectedTeamRepository]가 수집기가 올려둔 실제 데이터를
/// 읽는다. 화면(Provider, UI)은 이 인터페이스만 안다.
abstract class TeamRepository {
  Future<List<Team>> getTeams();
  Future<Team?> getTeamById(String id);

  /// 현재 시즌 순위표. 순위순으로 정렬돼 있다.
  Future<List<TeamStanding>> getStandings();

  /// 팀별 시즌 평균 기록(득점/실점/리바운드/야투% 등).
  Future<List<TeamSeasonStats>> getTeamSeasonStats();
}
