import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/player_display.dart';
import '../../data/models/player.dart';

/// 선수 얼굴 사진. 사진이 없거나 못 불러오면 이름 글자로 대신한다.
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
    final url = player.photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceElevated,
      child: url == null
          ? initial
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                // ESPN 사진은 가로로 긴 상반신이라 원 안에 얼굴이 오도록 채운다.
                fit: BoxFit.cover,
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (context, error, stackTrace) =>
                    Center(child: initial),
              ),
            ),
    );
  }
}
