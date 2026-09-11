import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/team.dart';
import '../../data/models/player.dart';
import '../../providers/news_providers.dart';
import '../../providers/onboarding_providers.dart';
import '../../providers/repository_providers.dart';
import '../common/league_switch.dart';
import '../follow/player_hub_screen.dart';
import '../follow/team_hub_screen.dart';
import 'widgets/followed_game_section.dart';
import 'widgets/news_cards.dart';

/// 홈 탭: 리그 전환(KBL / NBA)에 따라 그 리그 뉴스 한 섹션을 보여준다.
///
/// KBL 섹션에는 해외파 한국 선수 소식도 함께 들어 있다. 기사는 GitHub
/// Actions가 네이버 뉴스에서 모아둔 것을 그대로 쓴다. 맨 위 한 건은 큰
/// 썸네일의 헤드라인 카드로, 나머지는 작은 정사각 썸네일 리스트로 보여주고,
/// 누르면 원문을 앱 안에서 연다.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(newsFeedProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: Column(
        children: [
          const LeagueSwitch(),
          const _FollowChips(),
          Expanded(
            child: feedAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (err, _) => _NewsError(
                message: err is Exception ? '$err' : '뉴스를 불러오지 못했어요.',
                onRetry: () => ref.read(newsFeedProvider.notifier).retry(),
              ),
              data: (feed) {
                if (feed.articles.isEmpty) {
                  return _EmptyNews(
                    onRetry: () =>
                        ref.read(newsFeedProvider.notifier).refresh(),
                  );
                }
                final teamById = {
                  for (final t in teamsAsync.valueOrNull ?? <Team>[]) t.id: t,
                };
                final headline = feed.articles.first;
                final rest = feed.articles.skip(1).toList();

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      ref.read(newsFeedProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      // 팔로우한 팀의 오늘 경기가 있으면 뉴스보다 위에 온다.
                      const FollowedGameSection(),
                      NewsHeadlineCard(
                        article: headline,
                        team: teamById[headline.relatedTeamId],
                      ),
                      const SizedBox(height: 18),
                      for (var i = 0; i < rest.length; i++) ...[
                        if (i > 0) const Divider(height: 22),
                        NewsRow(
                          article: rest[i],
                          team: teamById[rest[i].relatedTeamId],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          '${relativeTime(feed.updatedAt)} 업데이트 · 네이버 뉴스 검색',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
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

/// 팔로우한 팀·선수 칩. 누르면 그 대상만 모아 놓은 전용 화면으로 간다.
///
/// 뉴스 분류는 맨 위 리그 전환 하나로 정하므로 분류 칩은 두지 않는다.
/// 팔로우 수만큼 늘어나므로 가로로 스크롤하고, 팔로우가 없으면 줄째 숨긴다.
class _FollowChips extends ConsumerWidget {
  const _FollowChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedTeamIds = ref.watch(followedTeamIdsProvider);
    final followedPlayerIds = ref.watch(followedPlayerIdsProvider);
    final teams = (ref.watch(teamsProvider).valueOrNull ?? <Team>[])
        .where((t) => followedTeamIds.contains(t.id))
        .toList();
    final players = (ref.watch(allPlayersProvider).valueOrNull ?? <Player>[])
        .where((p) => followedPlayerIds.contains(p.id))
        .toList();
    if (teams.isEmpty && players.isEmpty) return const SizedBox(height: 8);

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        children: [
          for (final team in teams) ...[
            _Chip(
              label: team.shortName,
              active: false,
              accent: team.primaryColor,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TeamHubScreen(team: team)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          for (final player in players) ...[
            _Chip(
              label: player.name,
              active: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerHubScreen(player: player),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// 팀 칩일 때 앞에 찍는 팀 컬러 점.
  final Color? accent;

  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.textPrimary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (accent != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NewsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 44,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNews extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyNews({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('아직 새 소식이 없어요', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('새로고침'),
          ),
        ],
      ),
    );
  }
}
