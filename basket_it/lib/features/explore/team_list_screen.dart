import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/team.dart';
import '../../providers/follow_actions.dart';
import '../../providers/onboarding_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/team_logo_placeholder.dart';
import 'team_detail_screen.dart';

/// 탐색 - 팀 정보 화면: 팀을 고르면 팀 상세(로스터/팀 성적)로 이동.
/// 언제든 팀을 팔로우/언팔로우할 수 있다.
class TeamListScreen extends ConsumerWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsProvider);
    final followedIds = ref.watch(followedTeamIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('팀 정보')),
      body: teamsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
        data: (teams) {
          final followedTeams = teams
              .where((t) => followedIds.contains(t.id))
              .toList();
          return CustomScrollView(
            slivers: [
              if (followedTeams.isNotEmpty)
                SliverToBoxAdapter(
                  child: _FollowingStrip(teams: followedTeams),
                ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.3,
                      ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final team = teams[index];
                    return _TeamTile(
                      team: team,
                      followed: followedIds.contains(team.id),
                    );
                  }, childCount: teams.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FollowingStrip extends ConsumerWidget {
  final List<Team> teams;

  const _FollowingStrip({required this.teams});

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
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: GestureDetector(
                    onTap: () => toggleTeamFollow(ref, team.id),
                    child: SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          TeamLogoPlaceholder(
                            team: team,
                            size: 52,
                            selected: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            team.shortName,
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

class _TeamTile extends ConsumerWidget {
  final Team team;
  final bool followed;

  const _TeamTile({required this.team, required this.followed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: followed ? AppColors.primary : AppColors.border,
          width: followed ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          TeamLogoPlaceholder(team: team, size: 36),
          const SizedBox(width: 10),
          // 팀 이름을 탭했을 때만 팀 상세로 이동한다(타일 전체가 아니라).
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TeamDetailScreen(team: team),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.city, style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => toggleTeamFollow(ref, team.id),
            icon: Icon(
              followed ? Icons.check_circle : Icons.add_circle_outline,
              color: followed ? AppColors.primary : AppColors.textTertiary,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}
