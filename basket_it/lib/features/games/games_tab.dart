import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common/league_switch.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/game.dart';
import '../../providers/game_providers.dart';
import '../../providers/onboarding_providers.dart';
import '../../providers/repository_providers.dart';
import 'game_detail_screen.dart';
import 'widgets/date_calendar_bar.dart';
import 'widgets/game_card.dart';

/// 게임 탭: 날짜 캘린더 + 선택한 날짜의 경기 목록.
class GamesTab extends ConsumerWidget {
  const GamesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedGameDateProvider);
    final gamesAsync = ref.watch(gamesByDateProvider(selectedDate));
    final teamsAsync = ref.watch(teamsProvider);
    final followedIds = ref.watch(followedTeamIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('게임')),
      body: Column(
        children: [
          const LeagueSwitch(),
          const SizedBox(height: 4),
          const DateCalendarBar(),
          const SizedBox(height: 4),
          Expanded(
            child: teamsAsync.when(
              loading: () => const _Loading(),
              error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
              data: (teams) {
                final teamById = {for (final t in teams) t.id: t};
                return gamesAsync.when(
                  loading: () => const _Loading(),
                  error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
                  data: (games) {
                    if (games.isEmpty) {
                      return Center(
                        child: Text(
                          '이 날짜엔 예정된 경기가 없어요',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }
                    final sorted = _sortWithFollowedFirst(games, followedIds);
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      itemCount: sorted.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final game = sorted[index];
                        final home = teamById[game.homeTeamId];
                        final away = teamById[game.awayTeamId];
                        if (home == null || away == null) {
                          return const SizedBox.shrink();
                        }
                        return GameCard(
                          game: game,
                          homeTeam: home,
                          awayTeam: away,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GameDetailScreen(
                                  game: game,
                                  homeTeam: home,
                                  awayTeam: away,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Game> _sortWithFollowedFirst(List<Game> games, Set<String> followed) {
    final pinned = <Game>[];
    final rest = <Game>[];
    for (final g in games) {
      if (followed.contains(g.homeTeamId) || followed.contains(g.awayTeamId)) {
        pinned.add(g);
      } else {
        rest.add(g);
      }
    }
    return [...pinned, ...rest];
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
