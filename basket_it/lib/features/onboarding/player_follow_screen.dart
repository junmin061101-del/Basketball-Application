import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/player_display.dart';
import '../../data/models/player.dart';
import '../../providers/onboarding_providers.dart';
import '../../providers/repository_providers.dart';
import '../explore/player_sort.dart';
import 'login_screen.dart';

/// 온보딩 - 팔로우할 선수 선택 화면.
///
/// 앞 단계에서 고른 팀의 선수가 가나다순으로 먼저 나오고, 이름으로 검색할 수 있다.
class PlayerFollowScreen extends ConsumerWidget {
  const PlayerFollowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersByFollowersProvider);
    final followedIds = ref.watch(followedPlayerIdsProvider);
    final query = ref.watch(playerSearchQueryProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '좋아하는 선수를 팔로우하세요',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _listHint(ref),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                onChanged: (value) =>
                    ref.read(playerSearchQueryProvider.notifier).state =
                        value,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: '선수 이름으로 검색',
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: playersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
                data: (allPlayers) {
                  final teamNameOf = <String, String>{
                    for (final t in teamsAsync.valueOrNull ?? [])
                      t.id: '${t.city} ${t.name}',
                  };
                  // 바로 앞 단계에서 팀을 골랐으므로, 그 팀 선수를 먼저
                  // 가나다순으로 보여주는 편이 찾기 쉽다.
                  final players = sortPlayers(
                    allPlayers,
                    sort: PlayerSort.myTeams,
                    followedTeamIds: ref.watch(followedTeamIdsProvider),
                  );
                  final filtered = query.trim().isEmpty
                      ? players
                      : players
                            .where((p) => p.name.contains(query.trim()))
                            .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        '검색 결과가 없어요',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final player = filtered[index];
                      final selected = followedIds.contains(player.id);
                      return _PlayerRow(
                        rank: player.backNumber,
                        player: player,
                        teamLabel: teamNameOf[player.teamId] ?? '',
                        selected: selected,
                        onTap: () {
                          final next = {...followedIds};
                          if (selected) {
                            next.remove(player.id);
                          } else {
                            next.add(player.id);
                          }
                          ref.read(followedPlayerIdsProvider.notifier).state =
                              next;
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text('다음'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  /// 왼쪽에 흐리게 두는 등번호.
  final int rank;
  final Player player;
  final String teamLabel;
  final bool selected;
  final VoidCallback onTap;

  const _PlayerRow({
    required this.rank,
    required this.player,
    required this.teamLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surfaceElevated,
              child: Text(
                playerInitial(player.name),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$teamLabel · ${player.positionText}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _FollowButton(selected: selected, onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _FollowButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          selected ? '팔로잉' : '팔로우',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 목록이 어떤 순서인지 알려주는 안내 문구.
String _listHint(WidgetRef ref) {
  final followedTeams = ref.watch(followedTeamIdsProvider);
  if (followedTeams.isEmpty) return '이름 가나다순으로 보여드려요.';
  return '팔로우한 팀의 선수를 가나다순으로 먼저 보여드려요.';
}
