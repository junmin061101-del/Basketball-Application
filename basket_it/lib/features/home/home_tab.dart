import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/league.dart';
import '../../data/models/player.dart';
import '../../data/models/team.dart';
import '../../providers/my_team_providers.dart';
import '../../providers/news_providers.dart';
import '../../providers/onboarding_providers.dart';
import '../../providers/repository_providers.dart';
import '../common/league_switch.dart';
import '../follow/player_hub_screen.dart';
import 'widgets/my_team_card.dart';
import 'widgets/news_cards.dart';

/// 홈 탭: 리그 전환(KBL / NBA) 아래로 **내 팀**을 먼저, 그 리그 뉴스를 그 다음에 보여준다.
///
/// 내 팀 카드는 팔로우한 팀의 순위·연승/연패·앞뒤 팀과의 게임차·최근 5경기·
/// 오늘(없으면 최근) 경기를 담는다. 뉴스는 KBL과 NBA를 섞지 않고 고른 리그
/// 기사만 보여준다(수집기가 기사 내용으로 리그를 다시 가른다). 맨 위 한 건은
/// 큰 썸네일의 헤드라인 카드, 나머지는 작은 썸네일 목록이며 누르면 원문을 연다.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final league = ref.watch(selectedLeagueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: Column(
        children: [
          const LeagueSwitch(),
          const _FollowChips(),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(myTeamSummaryProvider);
                await ref.read(newsFeedProvider.notifier).refresh();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  const MyTeamSection(),
                  const SizedBox(height: 28),
                  _SectionTitle(league == League.kbl ? 'KBL 뉴스' : 'NBA 뉴스'),
                  const SizedBox(height: 12),
                  const _NewsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// 고른 리그의 뉴스 목록. 불러오기·실패·빈 상태를 목록 자리에서 보여준다.
class _NewsSection extends ConsumerWidget {
  const _NewsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(newsFeedProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return feedAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (err, _) => _NewsError(
        message: err is Exception ? '$err' : '뉴스를 불러오지 못했어요.',
        onRetry: () => ref.read(newsFeedProvider.notifier).retry(),
      ),
      data: (feed) {
        if (feed.articles.isEmpty) {
          return _EmptyNews(
            onRetry: () => ref.read(newsFeedProvider.notifier).refresh(),
          );
        }
        final teamById = {
          for (final t in teamsAsync.valueOrNull ?? <Team>[]) t.id: t,
        };
        final headline = feed.articles.first;
        final rest = feed.articles.skip(1).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NewsHeadlineCard(
              article: headline,
              team: teamById[headline.relatedTeamId],
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < rest.length; i++) ...[
              if (i > 0) const Divider(height: 22),
              NewsRow(article: rest[i], team: teamById[rest[i].relatedTeamId]),
            ],
            const SizedBox(height: 20),
            Center(
              child: Text(
                '${relativeTime(feed.updatedAt)} 업데이트 · 네이버 뉴스 검색',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 팔로우한 선수 칩. 누르면 그 선수만 모아 놓은 전용 화면으로 간다.
///
/// 팀은 아래 내 팀 카드가 맡는다. 팔로우 수만큼 늘어나므로 가로로 스크롤하고,
/// 팔로우한 선수가 없으면 줄째 숨긴다.
class _FollowChips extends ConsumerWidget {
  const _FollowChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedPlayerIds = ref.watch(followedPlayerIdsProvider);
    final players = (ref.watch(allPlayersProvider).valueOrNull ?? <Player>[])
        .where((p) => followedPlayerIds.contains(p.id))
        .toList();
    if (players.isEmpty) return const SizedBox(height: 8);

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        children: [
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

  const _Chip({required this.label, required this.active, required this.onTap});

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
