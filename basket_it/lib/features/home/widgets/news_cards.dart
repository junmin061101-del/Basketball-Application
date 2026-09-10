import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/news_article.dart';
import '../../../data/models/team.dart';
import '../../../providers/news_providers.dart';

/// 홈·팀·선수 화면이 함께 쓰는 뉴스 카드들.
///
/// 어느 화면에서 보든 기사가 같은 모양으로 보이도록 한 곳에 모아 둔다.

/// 가장 최신 기사 한 건. 큰 썸네일 + 팀 배지 + 굵은 제목 + 한 줄 요약.
class NewsHeadlineCard extends ConsumerWidget {
  final NewsArticle article;
  final Team? team;

  const NewsHeadlineCard({
    super.key,
    required this.article,
    required this.team,
  });

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
                NewsThumbnail(article: article, team: team, height: 188),
                Positioned(
                  left: 12,
                  top: 12,
                  child: NewsTeamBadge(article: article, team: team),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NewsMetaLine(article: article),
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
class NewsRow extends ConsumerWidget {
  final NewsArticle article;
  final Team? team;

  const NewsRow({super.key, required this.article, required this.team});

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
                child: NewsThumbnail(article: article, team: team, height: 86),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NewsMetaLine(article: article),
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
class NewsThumbnail extends StatelessWidget {
  final NewsArticle article;
  final Team? team;
  final double height;

  const NewsThumbnail({
    super.key,
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
        errorBuilder: (_, _, _) => placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder(showIcon: false);
        },
      );
    }
    return placeholder();
  }

  Color get baseColor =>
      team?.primaryColor ??
      (article.category == NewsCategory.overseas
          ? const Color(0xFF1C3F94)
          : AppColors.primary);

  Widget placeholder({bool showIcon = true}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.5),
            baseColor.withValues(alpha: 0.18),
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
class NewsTeamBadge extends StatelessWidget {
  final NewsArticle article;
  final Team? team;

  const NewsTeamBadge({super.key, required this.article, required this.team});

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
class NewsMetaLine extends StatelessWidget {
  final NewsArticle article;

  const NewsMetaLine({super.key, required this.article});

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
            '${article.source} · ${relativeTime(article.publishedAt)}',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

String relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays == 1) return '어제';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return '${time.month}월 ${time.day}일';
}
