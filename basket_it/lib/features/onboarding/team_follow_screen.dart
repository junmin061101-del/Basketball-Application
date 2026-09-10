import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/team.dart';
import '../../providers/onboarding_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/team_logo_placeholder.dart';
import 'player_follow_screen.dart';

/// 온보딩 - 팔로우할 팀 선택 화면.
class TeamFollowScreen extends ConsumerWidget {
  const TeamFollowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(teamsProvider);
    final followedIds = ref.watch(followedTeamIdsProvider);

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
                    '응원하는 팀을 선택하세요',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '여러 팀을 선택할 수 있어요. 나중에 언제든 바꿀 수 있어요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: teamsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => Center(
                  child: Text('불러오지 못했어요: $err'),
                ),
                data: (teams) => GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    final team = teams[index];
                    final selected = followedIds.contains(team.id);
                    return _TeamTile(
                      team: team,
                      selected: selected,
                      onTap: () {
                        final next = {...followedIds};
                        if (selected) {
                          next.remove(team.id);
                        } else {
                          next.add(team.id);
                        }
                        ref.read(followedTeamIdsProvider.notifier).state =
                            next;
                      },
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlayerFollowScreen(),
                      ),
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

class _TeamTile extends StatelessWidget {
  final Team team;
  final bool selected;
  final VoidCallback onTap;

  const _TeamTile({
    required this.team,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? team.primaryColor : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            TeamLogoPlaceholder(team: team, size: 40, selected: selected),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.city,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
