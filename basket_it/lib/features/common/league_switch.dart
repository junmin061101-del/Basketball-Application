import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/league.dart';
import '../../providers/repository_providers.dart';

/// 화면 위쪽 제목 옆에 붙는 KBL / NBA 전환 스위치.
///
/// 디자인대로 검은 알약 안에서 고른 쪽만 흰 알약으로 바뀐다. 홈·게임·탐색 탭이
/// 함께 쓰고, 예측과 커뮤니티는 두 리그를 한곳에서 다루므로 붙이지 않는다.
class LeagueSwitch extends ConsumerWidget {
  /// 온보딩처럼 화면 너비를 꽉 채워야 하는 곳은 true.
  final bool expanded;

  const LeagueSwitch({super.key, this.expanded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedLeagueProvider);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(expanded ? 14 : 20),
      ),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final league in League.values)
            if (expanded)
              Expanded(child: _button(ref, league, league == selected))
            else
              _button(ref, league, league == selected),
        ],
      ),
    );
  }

  Widget _button(WidgetRef ref, League league, bool active) => _LeagueButton(
    league: league,
    active: active,
    expanded: expanded,
    onTap: () => ref.read(selectedLeagueProvider.notifier).state = league,
  );
}

class _LeagueButton extends StatelessWidget {
  final League league;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  const _LeagueButton({
    required this.league,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 0 : 18,
          vertical: expanded ? 12 : 7,
        ),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(expanded ? 11 : 17),
        ),
        child: Text(
          league.label,
          style: TextStyle(
            fontSize: expanded ? 16 : 13,
            fontWeight: FontWeight.w800,
            color: active ? AppColors.textPrimary : Colors.white,
          ),
        ),
      ),
    );
  }
}
