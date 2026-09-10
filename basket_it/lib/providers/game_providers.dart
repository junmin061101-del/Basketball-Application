import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/game.dart';
import '../data/models/player_game_stats.dart';
import '../data/models/league.dart';
import '../data/repositories/game_repository.dart';
import '../data/repositories/nba_repositories.dart';
import 'repository_providers.dart';

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return switch (ref.watch(selectedLeagueProvider)) {
    League.kbl => MockGameRepository(),
    League.nba => NbaGameRepository(ref.watch(nbaSourceProvider)),
  };
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
