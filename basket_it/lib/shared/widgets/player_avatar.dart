import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/player_display.dart';
import '../../data/models/player.dart';

/// 선수 동그라미. 사진 사용 허가 전이라 이름 글자로 그린다.
class PlayerAvatar extends StatelessWidget {
  final Player player;
  final double radius;

  const PlayerAvatar({super.key, required this.player, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final initial = Text(
      playerInitial(player.name),
      style: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: radius * 0.65,
      ),
    );
    // 선수 사진은 사용 허가를 받기 전까지 쓰지 않는다. 이름 글자로만 그린다.
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceElevated,
      child: initial,
    );
  }
}
