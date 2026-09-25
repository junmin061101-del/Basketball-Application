import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/team.dart';
import '../../providers/onboarding_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/team_logo_placeholder.dart';
import '../common/league_switch.dart';
import 'player_follow_screen.dart';

/// 온보딩 - 팔로우할 팀 선택 화면.
///
/// 위쪽 리그 전환으로 KBL과 NBA 팀을 함께 고를 수 있다. 두 리그 팀 id는
/// 겹치지 않아(KBL "sk", NBA "13") 한 집합에 같이 담는다.
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
                  const Text(
                    '응원하는 팀을 선택하세요',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'KBL과 NBA 팀을 함께 고를 수 있어요\n나중에 언제든 바꿀 수 있어요',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: LeagueSwitch(expanded: true),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: teamsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => Center(child: Text('불러오지 못했어요: $err')),
                data: (teams) => GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.4,
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
                        ref.read(followedTeamIdsProvider.notifier).state = next;
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
                  // 리그를 바꾸면 다른 리그에서 고른 팀이 안 보이므로 합계를 알려준다.
                  child: Text(
                    followedIds.isEmpty
                        ? '다음'
                        : '다음 · ${followedIds.length}팀 선택',
                  ),
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
          color: AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.positive : AppColors.border,
            width: selected ? 1.6 : 1,
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
                  Text(team.city, style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
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
