import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/player_display.dart';
import '../../data/models/player.dart';
import '../../data/player_photos.dart';

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
    // 앱에 넣어 둔 사진이 있으면 그걸 쓴다. KBL 서버에서 바로 불러오면 웹에서는
    // 브라우저가 <img>로 그려야 해서, 목록을 넘길 때 화면이 끊긴다.
    final asset = playerPhotoAsset(player.id);
    final url = player.photoUrl;
    final size = radius * 2;
    // 보이는 크기로만 풀어 둔다. 목록에서 50장을 원본 크기로 풀면 그만큼 끊긴다.
    final decodeTo = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceElevated,
      child: asset == null && url == null
          ? initial
          : ClipOval(
              child: asset != null
                  ? Image.asset(
                      asset,
                      key: ValueKey(player.id),
                      width: size,
                      height: size,
                      cacheWidth: decodeTo,
                      cacheHeight: decodeTo,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Center(child: initial),
                    )
                  : Image.network(
                      url!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      errorBuilder: (context, error, stackTrace) =>
                          Center(child: initial),
                    ),
            ),
    );
  }
}
