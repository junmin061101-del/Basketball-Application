import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/main_tab_provider.dart';
import '../common/page_header.dart';
import '../legal/legal_footer.dart';

import '../../core/theme/app_colors.dart';
import 'standings_screen.dart';
import 'stat_leaders_screen.dart';
import 'player_search_screen.dart';
import 'team_list_screen.dart';

/// 탐색 탭: 4개의 큰 메뉴 → 각각 상세 화면으로 진입.
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const PageHeader(title: '탐색'),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.0,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _MenuCard(
                      icon: Icons.bar_chart_rounded,
                      title: '팀 순위',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StandingsScreen(),
                        ),
                      ),
                    ),
                    _MenuCard(
                      icon: Icons.people_alt_outlined,
                      title: '선수 정보',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PlayerSearchScreen(),
                        ),
                      ),
                    ),
                    _MenuCard(
                      // 팀 엠블럼을 떠올리게 하는 방패. (옷걸이 아이콘이었다)
                      icon: Icons.shield_outlined,
                      title: '팀 정보',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TeamListScreen(),
                        ),
                      ),
                    ),
                    _MenuCard(
                      icon: Icons.workspace_premium_outlined,
                      title: '랭킹',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const StatLeadersScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _PredictionBanner(),
                const LegalFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 예측 탭으로 보내는 어두운 배너.
class _PredictionBanner extends ConsumerWidget {
  const _PredictionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      // 하단 탭을 예측으로 바꾼다.
      onTap: () => ref.read(mainTabIndexProvider.notifier).state = 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '오늘의 실시간 경기 예측 참여하기',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 26, color: AppColors.textPrimary),
                const Spacer(),
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
