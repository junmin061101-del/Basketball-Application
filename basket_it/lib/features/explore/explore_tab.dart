import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('탐색')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.05,
          children: [
            _MenuCard(
              icon: Icons.leaderboard_rounded,
              title: '팀 순위',
              color: const Color(0xFF2A3F8F),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StandingsScreen()),
              ),
            ),
            _MenuCard(
              icon: Icons.person_search_rounded,
              title: '선수 정보',
              color: const Color(0xFF8E1B3A),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlayerSearchScreen()),
              ),
            ),
            _MenuCard(
              icon: Icons.groups_rounded,
              title: '팀 정보',
              color: const Color(0xFF1F7A4D),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TeamListScreen()),
              ),
            ),
            _MenuCard(
              icon: Icons.emoji_events_rounded,
              title: '스탯 리더',
              color: const Color(0xFFC8102E),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StatLeadersScreen()),
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
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 32),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
