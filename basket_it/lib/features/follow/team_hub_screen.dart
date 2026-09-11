import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/game.dart';
import '../../data/models/news_article.dart';
import '../../data/models/team.dart';
import '../../data/models/team_standing.dart';
import '../../providers/follow_feed_providers.dart';
import '../../providers/repository_providers.dart';
import '../explore/team_detail_screen.dart';
import '../games/game_detail_screen.dart';
import '../home/widgets/news_cards.dart';

/// 팔로우한 팀 하나에 관한 모든 것을 모아 보여주는 화면.
///
/// 프로필 헤더(로고·이름·순위) 아래로 다음 경기 → 최근 결과 → 팀 뉴스 순.
/// 뉴스는 홈과 같은 카드를 써서 어디서 보든 같은 모양이 되게 한다.
class TeamHubScreen extends ConsumerWidget {
  final Team team;

  const TeamHubScreen({super.key, required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(teamNewsProvider(team.id));
    final nextGameAsync = ref.watch(nextGameProvider(team.id));
    final recentAsync = ref.watch(
      recentResultsProvider((teamId: team.id, limit: 5)),
    );
    final teamById = {
      for (final t in ref.watch(teamsProvider).valueOrNull ?? <Team>[])
        t.id: t,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(team.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TeamDetailScreen(team: team)),
            ),
            child: const Text('선수단·기록'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _TeamHeader(team: team),
          const SizedBox(height: 20),

          _SectionTitle('다음 경기'),
          nextGameAsync.when(
            loading: () => const _SectionLoading(),
            error: (_, _) => const _SectionEmpty('경기 일정을 불러오지 못했어요'),
            data: (game) => game == null
                ? const _SectionEmpty('예정된 경기가 없어요')
                : _GameRow(game: game, teamId: team.id, teamById: teamById),
          ),
          const SizedBox(height: 22),

          _SectionTitle('최근 경기 결과'),
          recentAsync.when(
            loading: () => const _SectionLoading(),
            error: (_, _) => const _SectionEmpty('경기 결과를 불러오지 못했어요'),
            data: (games) => games.isEmpty
                ? const _SectionEmpty('최근 치른 경기가 없어요')
                : Column(
                    children: [
                      for (final game in games)
                        _GameRow(
                          game: game,
                          teamId: team.id,
                          teamById: teamById,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 22),

          _SectionTitle('${team.shortName} 뉴스'),
          newsAsync.when(
            loading: () => const _SectionLoading(),
            error: (_, _) => const _SectionEmpty('뉴스를 불러오지 못했어요'),
            data: (articles) => articles.isEmpty
                ? const _SectionEmpty('아직 이 팀 기사가 없어요')
                : _NewsList(articles: articles, teamById: teamById),
          ),
        ],
      ),
    );
  }
}

/// 로고 자리 + 팀 이름 + 순위/전적 요약.
class _TeamHeader extends ConsumerWidget {
  final Team team;

  const _TeamHeader({required this.team});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standings = ref.watch(standingsProvider).valueOrNull;
    final standing = standings?.where((s) => s.teamId == team.id).firstOrNull;
    // NBA는 컨퍼런스 안 순위("동부 3위")다. 30팀 전체 순번을 쓰면 틀린다.
    final rankLabel = standings == null
        ? null
        : rankLabelOf(standings, team.id);
    final form = ref.watch(recentFormProvider(team.id)).valueOrNull;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            team.primaryColor.withValues(alpha: 0.16),
            team.primaryColor.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          TeamCrest(team: team, size: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.city,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  team.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    ?rankLabel,
                    if (standing != null) '${standing.wins}승 ${standing.losses}패',
                    if (form != null && form.played > 0) '최근5 ${form.record}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 팀 로고. 엠블럼 파일([Team.logoAsset])이나 원격 로고([Team.logoUrl])가
/// 있으면 그리고, 없으면 팀 컬러 바탕에 이름 두 글자를 쓴다.
class TeamCrest extends StatelessWidget {
  final Team team;
  final double size;

  const TeamCrest({super.key, required this.team, required this.size});

  @override
  Widget build(BuildContext context) {
    final asset = team.logoAsset;
    if (asset != null) {
      return Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
    }
    final url = team.logoUrl;
    if (url != null) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: team.primaryColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        team.shortName.characters.take(2).toString(),
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w900,
          color: team.primaryColor,
        ),
      ),
    );
  }
}

/// 경기 한 줄: 상대 / 결과 또는 일시.
class _GameRow extends StatelessWidget {
  final Game game;
  final String teamId;
  final Map<String, Team> teamById;

  const _GameRow({
    required this.game,
    required this.teamId,
    required this.teamById,
  });

  @override
  Widget build(BuildContext context) {
    final isHome = game.homeTeamId == teamId;
    final opponentId = isHome ? game.awayTeamId : game.homeTeamId;
    final opponent = teamById[opponentId];
    final home = teamById[game.homeTeamId];
    final away = teamById[game.awayTeamId];

    final myScore = isHome ? game.homeScore : game.awayScore;
    final theirScore = isHome ? game.awayScore : game.homeScore;
    final finished = game.status == GameStatus.finished;
    final won = finished && teamWon(game, teamId);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: (home != null && away != null)
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GameDetailScreen(
                  game: game,
                  homeTeam: home,
                  awayTeam: away,
                ),
              ),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(
              isHome ? 'vs' : '@',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                opponent?.shortName ?? opponentId,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (finished) ...[
              Text(
                won ? '승' : '패',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: won ? AppColors.positive : AppColors.negative,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$myScore-$theirScore',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ] else
              Text(
                _shortWhen(game.startTime),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _shortWhen(DateTime t) =>
    '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 첫 기사는 큰 카드, 나머지는 목록. 홈과 같은 구성.
class _NewsList extends StatelessWidget {
  final List<NewsArticle> articles;
  final Map<String, Team> teamById;

  const _NewsList({required this.articles, required this.teamById});

  @override
  Widget build(BuildContext context) {
    final headline = articles.first;
    final rest = articles.skip(1).toList();
    return Column(
      children: [
        NewsHeadlineCard(
          article: headline,
          team: teamById[headline.relatedTeamId],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < rest.length; i++) ...[
          if (i > 0) const Divider(height: 22),
          NewsRow(article: rest[i], team: teamById[rest[i].relatedTeamId]),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primary,
        ),
      ),
    ),
  );
}

class _SectionEmpty extends StatelessWidget {
  final String text;

  const _SectionEmpty(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
    ),
  );
}
