import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/league.dart';
import '../../providers/repository_providers.dart';

/// 화면 위쪽에 놓는 KBL / NBA 전환 스위치.
///
/// 홈·게임·탐색 탭이 이걸 함께 쓴다. 예측과 커뮤니티는 두 리그를 한곳에서
/// 다루므로 붙이지 않는다.
class LeagueSwitch extends ConsumerWidget {
  const LeagueSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLeagueProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final league in League.values)
            Expanded(
              child: _LeagueButton(
                league: league,
                active: league == selected,
                onTap: () => ref.read(selectedLeagueProvider.notifier).state =
                    league,
              ),
            ),
        ],
      ),
    );
  }
}

class _LeagueButton extends StatelessWidget {
  final League league;
  final bool active;
  final VoidCallback onTap;

  const _LeagueButton({
    required this.league,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          league.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: active ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
