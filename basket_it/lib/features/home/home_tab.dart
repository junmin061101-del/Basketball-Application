import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/news_article.dart';
import '../../data/models/team.dart';
import '../../providers/news_providers.dart';
import '../../providers/repository_providers.dart';

/// 홈 탭: KBL 뉴스 + 해외파 한국 선수 뉴스.
///
/// 기사는 Cloud Functions(`getBasketballNews`)가 네이버 뉴스에서 모아준 것을
/// 그대로 쓴다. 맨 위 한 건은 큰 썸네일의 헤드라인 카드로, 나머지는 작은
/// 정사각 썸네일 리스트로 보여주고, 누르면 원문을 웹뷰로 연다.
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(newsCategoryFilterProvider);
    final feedAsync = ref.watch(newsFeedProvider);
    final teamsAsync = ref.watch(teamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('홈')),
      body: Column(
        children: [
          _CategoryChips(
            selected: filter,
            onSelected: (c) =>
                ref.read(newsCategoryFilterProvider.notifier).state = c,
          ),
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
                      _HeadlineCard(
                        article: headline,
                        team: teamById[headline.relatedTeamId],
                      ),
                      const SizedBox(height: 18),
                      for (var i = 0; i < rest.length; i++) ...[
                        if (i > 0) const Divider(height: 22),
                        _NewsRow(
                          article: rest[i],
                          team: teamById[rest[i].relatedTeamId],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          '${_relativeTime(feed.updatedAt)} 업데이트 · 네이버 뉴스 검색',
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

class _CategoryChips extends StatelessWidget {
  final NewsCategory? selected;
  final ValueChanged<NewsCategory?> onSelected;

  const _CategoryChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = <(String, NewsCategory?)>[
      ('전체', null),
      ('KBL', NewsCategory.kbl),
      ('해외파', NewsCategory.overseas),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          for (final (label, category) in items) ...[
            _Chip(
              label: label,
              active: selected == category,
              onTap: () => onSelected(category),
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

/// 가장 최신 기사 한 건. 큰 썸네일 + 팀 배지 + 굵은 제목 + 한 줄 요약.
class _HeadlineCard extends ConsumerWidget {
  final NewsArticle article;
  final Team? team;

  const _HeadlineCard({required this.article, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => ref.read(articleOpenerProvider)(context, article),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _Thumbnail(article: article, team: team, height: 188),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _TeamBadge(article: article, team: team),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaLine(article: article),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontSize: 20, height: 1.25),
                  ),
                  if (article.summary != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.summary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 헤드라인 아래로 이어지는 목록 카드. 작은 정사각 썸네일 + 제목만.
class _NewsRow extends ConsumerWidget {
  final NewsArticle article;
  final Team? team;

  const _NewsRow({required this.article, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => ref.read(articleOpenerProvider)(context, article),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 86,
                height: 86,
                child: _Thumbnail(article: article, team: team, height: 86),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaLine(article: article),
                  const SizedBox(height: 6),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(height: 1.3),
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

/// 썸네일 자리. 기사에 og:image가 있으면 그 이미지를, 없거나 실패하면
/// 관련 팀 컬러(해외파는 별도 톤)를 쓴 플레이스홀더를 그린다.
class _Thumbnail extends StatelessWidget {
  final NewsArticle article;
  final Team? team;
  final double height;

  const _Thumbnail({
    required this.article,
    required this.team,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final url = article.thumbnailUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        // 웹에서는 CanvasKit이 이미지를 canvas에 그리느라 CORS 헤더를 요구한다.
        // 그 헤더를 안 보내는 언론사(바스켓코리아 등) 사진이 통째로 안 나오므로,
        // 바이트를 못 받아오면 <img> 요소로 대신 띄운다. 모바일에는 영향 없다.
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        // 그래도 안 되면 플레이스홀더로 되돌린다.
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _placeholder(showIcon: false);
        },
      );
    }
    return _placeholder();
  }

  Color get _baseColor =>
      team?.primaryColor ??
      (article.category == NewsCategory.overseas
          ? const Color(0xFF1C3F94)
          : AppColors.primary);

  Widget _placeholder({bool showIcon = true}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _baseColor.withValues(alpha: 0.5),
            _baseColor.withValues(alpha: 0.18),
          ],
        ),
      ),
      child: showIcon
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -10,
                  bottom: -14,
                  child: Icon(
                    Icons.sports_basketball,
                    size: height * 0.85,
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

/// 썸네일 좌측 상단에 얹는 팀(또는 해외파) 배지.
class _TeamBadge extends StatelessWidget {
  final NewsArticle article;
  final Team? team;

  const _TeamBadge({required this.article, required this.team});

  @override
  Widget build(BuildContext context) {
    final label =
        team?.shortName ?? article.teamLabel ?? article.category.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// 분류 · 언론사 · 시간 한 줄.
class _MetaLine extends StatelessWidget {
  final NewsArticle article;

  const _MetaLine({required this.article});

  @override
  Widget build(BuildContext context) {
    final accent = article.category == NewsCategory.overseas
        ? const Color(0xFF1C3F94)
        : AppColors.primary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            article.category.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${article.source} · ${_relativeTime(article.publishedAt)}',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
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

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays == 1) return '어제';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${time.month}월 ${time.day}일';
}
