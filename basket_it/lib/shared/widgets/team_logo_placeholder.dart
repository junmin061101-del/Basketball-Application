import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/team.dart';

/// 실제 팀 로고 이미지가 준비되기 전까지 사용하는 플레이스홀더.
///
/// [Team.logoAsset]이 채워지면 이 위젯 내부에서 이미지로 교체하기만 하면
/// 되도록 호출부는 항상 이 위젯을 통해서만 팀 로고를 렌더링한다.
class TeamLogoPlaceholder extends StatelessWidget {
  final Team team;
  final double size;
  final bool selected;

  const TeamLogoPlaceholder({
    super.key,
    required this.team,
    this.size = 56,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoAsset = team.logoAsset;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: team.primaryColor.withValues(alpha: 0.18),
            border: Border.all(
              color: selected ? team.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: logoAsset == null
              ? Text(
                  team.shortName.length > 4
                      ? team.shortName.substring(0, 3)
                      : team.shortName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: team.primaryColor,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.24,
                    letterSpacing: -0.5,
                  ),
                )
              : Image.asset(logoAsset, width: size * 0.65),
        ),
        if (selected)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: team.primaryColor,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: Icon(Icons.check, size: size * 0.2, color: Colors.white),
            ),
          ),
      ],
    );
  }
}
