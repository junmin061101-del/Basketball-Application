import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/game.dart';
import '../data/models/player_game_stats.dart';
import '../data/repositories/collected_repositories.dart';
import '../data/repositories/game_repository.dart';
import 'repository_providers.dart';

/// 선택된 리그의 일정·결과·박스스코어. 두 리그 모두 수집기가 모은 실제 경기다.
final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return CollectedGameRepository(ref.watch(leagueSourceProvider));
});

/// 게임 탭에서 현재 선택된 날짜.
final selectedGameDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// 선택된 날짜의 경기 목록.
final gamesByDateProvider = FutureProvider.family<List<Game>, DateTime>((
  ref,
  date,
) {
  return ref.watch(gameRepositoryProvider).getGamesByDate(date);
});

/// 특정 경기의 박스스코어.
final boxScoreProvider = FutureProvider.family<List<PlayerGameStats>, Game>((
  ref,
  game,
) {
  return ref.watch(gameRepositoryProvider).getBoxScore(game);
});
