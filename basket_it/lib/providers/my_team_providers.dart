import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/my_team_summary.dart';
import 'game_providers.dart';
import 'repository_providers.dart';

/// 홈 "내 팀" 카드에서 고른 팀. null이면 팔로우한 팀 중 첫 번째.
final selectedMyTeamIdProvider = StateProvider<String?>((ref) => null);

/// 팀 하나의 순위·최근 경기 요약. 지금 고른 리그의 순위표와 경기에서 계산한다.
///
/// 비시즌에도 지난 시즌 마지막 경기와 다음 시즌 첫 경기가 보이도록 넉넉한
/// 기간을 본다(수집기가 지난 3시즌 경기를 올려 두었다).
final myTeamSummaryProvider = FutureProvider.family<MyTeamSummary, String>((
  ref,
  teamId,
) async {
  final now = DateTime.now();
  final standings = await ref.watch(standingsProvider.future);
  final games = await ref
      .watch(gameRepositoryProvider)
      .getGamesInRange(
        now.subtract(const Duration(days: 400)),
        now.add(const Duration(days: 120)),
      );
  return MyTeamSummary.build(
    teamId: teamId,
    standings: standings,
    games: games,
    now: now,
  );
});
