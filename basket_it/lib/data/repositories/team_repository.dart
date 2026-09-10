import '../mock/mock_kbl_data.dart';
import '../models/team.dart';
import '../models/team_season_stats.dart';
import '../models/team_standing.dart';
import '../../core/utils/stable_hash.dart';
import '../../core/utils/stable_random.dart';

/// 팀 데이터 접근을 추상화한 Repository.
///
/// 지금은 [MockTeamRepository]가 목업 데이터를 반환하지만, 실제 API가
/// 준비되면 이 인터페이스를 구현하는 `ApiTeamRepository` 하나로 교체하면
/// 앱의 나머지 부분(Provider, UI)은 변경할 필요가 없다.
abstract class TeamRepository {
  Future<List<Team>> getTeams();
  Future<Team?> getTeamById(String id);

  /// 현재 시즌 순위표. 승률 내림차순으로 정렬돼 있다.
  Future<List<TeamStanding>> getStandings();

  /// 팀별 시즌 평균 기록(득점/실점/리바운드/야투% 등).
  Future<List<TeamSeasonStats>> getTeamSeasonStats();
}

class MockTeamRepository implements TeamRepository {
  @override
  Future<List<Team>> getTeams() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return kMockTeams;
  }

  @override
  Future<Team?> getTeamById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return kMockTeams.firstWhere((team) => team.id == id);
    } catch (_) {
      return null;
    }
  }

  static const _gamesPlayed = 40;

  @override
  Future<List<TeamStanding>> getStandings() async {
    await Future.delayed(const Duration(milliseconds: 400));

    final unsorted = kMockTeams.map((team) {
      final rng = StableRandom(stableSeed(['standing', team.id]));
      final wins = 5 + rng.nextInt(31); // 5 ~ 35승
      return (teamId: team.id, wins: wins, losses: _gamesPlayed - wins);
    }).toList()..sort((a, b) => b.wins.compareTo(a.wins));

    final leader = unsorted.first;
    return unsorted.map((row) {
      final gamesBehind =
          ((leader.wins - row.wins) + (row.losses - leader.losses)) / 2;
      return TeamStanding(
        teamId: row.teamId,
        wins: row.wins,
        losses: row.losses,
        gamesBehind: gamesBehind,
      );
    }).toList();
  }

  @override
  Future<List<TeamSeasonStats>> getTeamSeasonStats() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return kMockTeams.map(_teamStatsFor).toList();
  }

  TeamSeasonStats _teamStatsFor(Team team) {
    final rng = StableRandom(stableSeed(['teamStats', team.id]));

    final fga = 62 + rng.nextDouble() * 12;
    final fgPct = 0.40 + rng.nextDouble() * 0.08;
    final fgm = fga * fgPct;

    final tpa = 20 + rng.nextDouble() * 8;
    final tpPct = 0.30 + rng.nextDouble() * 0.08;
    final tpm = tpa * tpPct;

    final fta = 14 + rng.nextDouble() * 8;
    final ftPct = 0.66 + rng.nextDouble() * 0.10;
    final ftm = fta * ftPct;
    final oreb = 7 + rng.nextDouble() * 5;
    final dreb = 22 + rng.nextDouble() * 6;

    return TeamSeasonStats(
      teamId: team.id,
      pointsFor: 2 * fgm + tpm + ftm,
      pointsAgainst: 70 + rng.nextDouble() * 20,
      rebounds: oreb + dreb,
      assists: 15 + rng.nextDouble() * 7,
      steals: 4 + rng.nextDouble() * 4,
      blocks: 1.5 + rng.nextDouble() * 3,
      fgm: fgm,
      fga: fga,
      tpm: tpm,
      tpa: tpa,
      ftm: ftm,
      fta: fta,
      oreb: oreb,
      dreb: dreb,
      tov: 10 + rng.nextDouble() * 4,
      pf: 16 + rng.nextDouble() * 4,
    );
  }
}
