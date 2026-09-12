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

/// 지금 리그에서 경기가 있는 날짜들(오름차순).
///
/// 날짜 바의 점 표시와 "다음 경기일로 이동"에 쓴다. 비시즌에는 몇 주씩 빈
/// 날이 이어져, 날짜를 하나씩 넘겨서는 경기를 찾기 어렵다. 수집된 일정이
/// 지난 3시즌 경기까지 올라와 있어 과거는 3년 넘게, 앞으로는 다음 시즌
/// 일정까지 넉넉히 본다.
final gameDaysProvider = FutureProvider<List<DateTime>>((ref) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final games = await ref
      .watch(gameRepositoryProvider)
      .getGamesInRange(
        today.subtract(const Duration(days: 365 * 3 + 120)),
        today.add(const Duration(days: 400)),
      );
  return {
    for (final g in games) DateTime(g.date.year, g.date.month, g.date.day),
  }.toList()..sort();
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
