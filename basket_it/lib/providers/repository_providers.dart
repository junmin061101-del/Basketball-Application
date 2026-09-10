import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/player.dart';
import '../data/models/player_bio.dart';
import '../data/models/player_season_stats.dart';
import '../data/models/team.dart';
import '../data/models/team_season_stats.dart';
import '../data/models/team_standing.dart';
import '../data/repositories/player_repository.dart';
import '../data/repositories/team_repository.dart';

/// Repository 구현체 주입 지점.
///
/// 실제 API 연동 시 아래 두 줄만 `ApiTeamRepository()` / `ApiPlayerRepository()`로
/// 교체하면 앱 전체의 데이터 소스가 바뀐다.
final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return MockTeamRepository();
});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return MockPlayerRepository();
});

/// 전체 팀 목록.
final teamsProvider = FutureProvider<List<Team>>((ref) {
  return ref.watch(teamRepositoryProvider).getTeams();
});

/// 현재 시즌 순위표(승률 내림차순).
final standingsProvider = FutureProvider<List<TeamStanding>>((ref) {
  return ref.watch(teamRepositoryProvider).getStandings();
});

/// 팀별 시즌 평균 기록(득점/실점/리바운드/야투% 등).
final teamSeasonStatsProvider = FutureProvider<List<TeamSeasonStats>>((ref) {
  return ref.watch(teamRepositoryProvider).getTeamSeasonStats();
});

/// 팔로워 수 기준 정렬된 전체 선수 목록.
final playersByFollowersProvider = FutureProvider<List<Player>>((ref) {
  return ref.watch(playerRepositoryProvider).getPlayersSortedByFollowers();
});

/// 전체 선수 목록(정렬 없음). id로 선수를 빠르게 찾을 때 사용.
final allPlayersProvider = FutureProvider<List<Player>>((ref) {
  return ref.watch(playerRepositoryProvider).getPlayers();
});

/// 특정 팀의 로스터.
final teamRosterProvider = FutureProvider.family<List<Player>, String>((
  ref,
  teamId,
) {
  return ref.watch(playerRepositoryProvider).getPlayersByTeam(teamId);
});

/// 선수 프로필 헤더용 신상 정보.
final playerBioProvider = FutureProvider.family<PlayerBio, Player>((
  ref,
  player,
) {
  return ref.watch(playerRepositoryProvider).getPlayerBio(player);
});

/// 선수의 시즌별 전체 스탯(최근 시즌이 0번 인덱스).
final seasonStatsHistoryProvider =
    FutureProvider.family<List<PlayerSeasonStats>, Player>((ref, player) {
      return ref.watch(playerRepositoryProvider).getSeasonStatsHistory(player);
    });

/// 전체 선수의 이번 시즌 스탯. 스탯 리더 랭킹에 사용.
final currentSeasonStatsAllProvider = FutureProvider<List<PlayerSeasonStats>>((
  ref,
) {
  return ref
      .watch(playerRepositoryProvider)
      .getCurrentSeasonStatsForAllPlayers();
});
