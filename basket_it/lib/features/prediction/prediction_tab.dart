import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/game.dart';
import '../../data/models/team.dart';
import '../../providers/prediction_providers.dart';
import '../../providers/repository_providers.dart';
import 'leaderboard_view.dart';
import 'prediction_game_card.dart';

/// 승부예측 탭: 예측하기(오늘~7일치 경기) / 랭킹.
class PredictionTab extends StatelessWidget {
  const PredictionTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('승부예측'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '예측하기'),
              Tab(text: '랭킹'),
            ],
          ),
        ),
        body: const TabBarView(children: [_PredictionList(), LeaderboardView()]),
      ),
    );
  }
}

class _PredictionList extends ConsumerWidget {
  const _PredictionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(predictionGamesProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return teamsAsync.when(
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
                  '예측할 경기가 없어요',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            final sections = _groupByDate(games);
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.refresh(predictionGamesProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '예측은 경기 시작 1시간 전까지 바꿀 수 있어요. 결과가 나오면 랭킹에 반영돼요.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 6),
                      child: Text(
                        section.label,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    for (final game in section.games) ...[
                      PredictionGameCard(
                        game: game,
                        homeTeam: teamById[game.homeTeamId],
                        awayTeam: teamById[game.awayTeamId],
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<({String label, List<Game> games})> _groupByDate(List<Game> games) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final map = <DateTime, List<Game>>{};
    for (final g in games) {
      map.putIfAbsent(g.date, () => []).add(g);
    }
    final keys = map.keys.toList()..sort();
    return [
      for (final d in keys)
        (
          label:
              '${d == today ? '오늘 · ' : (d.difference(today).inDays == 1 ? '내일 · ' : '')}'
              '${d.month}월 ${d.day}일 (${weekdays[d.weekday - 1]})',
          games: map[d]!,
        ),
    ];
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

/// 다른 파일에서도 쓰는 팀 이름 헬퍼.
String teamLabel(Team? team, String fallbackId) =>
    team?.fullName ?? fallbackId.toUpperCase();
