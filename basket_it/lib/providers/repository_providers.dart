import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/player.dart';
import '../data/models/player_bio.dart';
import '../data/models/player_season_stats.dart';
import '../data/models/team.dart';
import '../data/models/team_season_stats.dart';
import '../data/models/team_standing.dart';
import '../data/models/league.dart';
import '../data/repositories/nba_repositories.dart';
import '../data/repositories/nba_source.dart';
import '../data/repositories/player_repository.dart';
import '../data/repositories/team_repository.dart';

/// 지금 보고 있는 리그. 홈·게임·탐색 탭이 이 값을 따라간다.
final selectedLeagueProvider = StateProvider<League>((ref) => League.kbl);

/// NBA 정적 데이터(팀·순위·일정·로스터)를 읽는 곳. 결과를 캐시한다.
final nbaSourceProvider = Provider<NbaSource>((ref) => NbaSource());

/// Repository 구현체 주입 지점.
///
/// 리그를 바꾸면 여기서 구현체가 통째로 바뀌고, 이 provider를 지켜보는
/// 화면들이 알아서 새 데이터를 받는다. KBL은 아직 목업이고, NBA는
/// ESPN에서 모은 실제 데이터다.
final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return switch (ref.watch(selectedLeagueProvider)) {
    League.kbl => MockTeamRepository(),
    League.nba => NbaTeamRepository(ref.watch(nbaSourceProvider)),
  };
});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return switch (ref.watch(selectedLeagueProvider)) {
    League.kbl => MockPlayerRepository(),
    League.nba => NbaPlayerRepository(ref.watch(nbaSourceProvider)),
  };
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
