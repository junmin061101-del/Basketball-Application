import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/league_switch.dart';
import '../common/page_header.dart';

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

    final standings = ref.watch(standingsProvider).valueOrNull ?? const [];
    final recordByTeam = {
      for (final s in standings)
        if (s.gamesPlayed > 0) s.teamId: '${s.wins}승 ${s.losses}패',
    };

    return Scaffold(
      body: Column(
        children: [
          const PageHeader(title: 'GAMES', trailing: LeagueSwitch()),
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
                      return _NoGames(selectedDate: selectedDate);
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
                          homeRecord: recordByTeam[home.id],
                          awayRecord: recordByTeam[away.id],
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

/// 고른 날짜에 경기가 없을 때.
///
/// 비시즌이나 휴식일에 빈 화면만 보이면 경기가 없는 건지 앱이 고장 난 건지
/// 알 수 없다. 가장 가까운 앞뒤 경기일로 바로 갈 수 있게 한다.
class _NoGames extends ConsumerWidget {
  final DateTime selectedDate;

  const _NoGames({required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(gameDaysProvider).valueOrNull ?? const <DateTime>[];
    DateTime? next;
    DateTime? previous;
    for (final day in days) {
      if (day.isAfter(selectedDate)) {
        next ??= day;
      } else if (day.isBefore(selectedDate)) {
        previous = day;
      }
    }
    final nextDay = next;
    final previousDay = previous;
    void select(DateTime day) =>
        ref.read(selectedGameDateProvider.notifier).state = day;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '이 날짜엔 경기가 없어요',
              style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
            ),
            if (nextDay != null) ...[
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => select(nextDay),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('다음 경기 · ${_dayLabel(nextDay)}'),
                ),
              ),
            ],
            if (previousDay != null) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => select(previousDay),
                child: Text(
                  '지난 경기 · ${_dayLabel(previousDay)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "10월 4일 (일)". 올해가 아니면 연도를 붙인다.
String _dayLabel(DateTime day) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final year = day.year == DateTime.now().year ? '' : '${day.year}년 ';
  return '$year${day.month}월 ${day.day}일 (${weekdays[day.weekday - 1]})';
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
