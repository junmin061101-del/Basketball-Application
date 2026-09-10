import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/player.dart';
import '../../providers/follow_actions.dart';
import '../../providers/onboarding_providers.dart';
import '../../providers/repository_providers.dart';
import '../player/player_detail_screen.dart';
import 'player_sort.dart';

/// 탐색 - 선수 정보 화면: 검색해서 선수를 찾고, 선택하면 선수 상세로 이동.
/// 언제든 선수를 팔로우/언팔로우할 수 있다.
class PlayerSearchScreen extends ConsumerStatefulWidget {
  const PlayerSearchScreen({super.key});

  @override
  ConsumerState<PlayerSearchScreen> createState() =>
      _PlayerSearchScreenState();
}

class _PlayerSearchScreenState extends ConsumerState<PlayerSearchScreen> {
  String _query = '';

  /// 기본은 "내 팀 먼저". 팔로우한 팀 선수를 가나다순으로 먼저 보여준다.
  PlayerSort _sort = PlayerSort.myTeams;

  @override
  Widget build(BuildContext context) {
    final playersAsync = ref.watch(playersByFollowersProvider);
    final teamsAsync = ref.watch(teamsProvider);
    final followedIds = ref.watch(followedPlayerIdsProvider);
    final followedTeamIds = ref.watch(followedTeamIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('선수 정보')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
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
          _SortChips(
            selected: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
          ),
          Expanded(
            child: teamsAsync.when(
              loading: () => const _Loading(),
              error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
              data: (teams) {
                final teamLabelOf = {
                  for (final t in teams) t.id: '${t.city} ${t.name}',
                };
                return playersAsync.when(
                  loading: () => const _Loading(),
                  error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
                  data: (allPlayers) {
                    final players = sortPlayers(
                      allPlayers,
                      sort: _sort,
                      followedTeamIds: followedTeamIds,
                      teamNameOf: (id) => teamLabelOf[id] ?? id,
                    );
                    final filtered = _query.trim().isEmpty
                        ? players
                        : players
                              .where((p) => p.name.contains(_query.trim()))
                              .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          '검색 결과가 없어요',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }
                    final followedPlayers = _query.trim().isEmpty
                        ? players
                              .where((p) => followedIds.contains(p.id))
                              .toList()
                        : const <Player>[];
                    return CustomScrollView(
                      slivers: [
                        if (followedPlayers.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _FollowingStrip(players: followedPlayers),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          sliver: SliverList.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (context, index) {
                              final player = filtered[index];
                              return _PlayerRow(
                                player: player,
                                teamLabel: teamLabelOf[player.teamId] ?? '',
                                followed: followedIds.contains(player.id),
                              );
                            },
                          ),
                        ),
                      ],
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
}

class _FollowingStrip extends ConsumerWidget {
  final List<Player> players;

  const _FollowingStrip({required this.players});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '팔로잉 · 탭하면 언팔로우',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: GestureDetector(
                    onTap: () => togglePlayerFollow(ref, player.id),
                    child: SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: AppColors.surfaceElevated,
                                child: Text(
                                  player.name.substring(
                                    player.name.length - 1,
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary,
                                    border: Border.all(
                                      color: AppColors.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 11,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends ConsumerWidget {
  final Player player;
  final String teamLabel;
  final bool followed;

  const _PlayerRow({
    required this.player,
    required this.teamLabel,
    required this.followed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlayerDetailScreen(player: player),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surfaceElevated,
              child: Text(
                player.name.substring(player.name.length - 1),
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
                    '$teamLabel · ${player.position.label} · #${player.backNumber}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _FollowButton(
              followed: followed,
              onTap: () => togglePlayerFollow(ref, player.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool followed;
  final VoidCallback onTap;

  const _FollowButton({required this.followed, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: followed ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: followed ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          followed ? '팔로잉' : '팔로우',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: followed ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
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

/// 정렬 방식 선택 칩. 홈 필터 칩과 같은 모양을 쓴다.
class _SortChips extends StatelessWidget {
  final PlayerSort selected;
  final ValueChanged<PlayerSort> onSelected;

  const _SortChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        children: [
          for (final sort in PlayerSort.values) ...[
            _SortChip(
              label: sort.label,
              active: sort == selected,
              onTap: () => onSelected(sort),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.textPrimary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
