import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 아직 구현되지 않은 탭/화면에 사용하는 공용 플레이스홀더.
class ComingSoonPlaceholder extends StatelessWidget {
  final String label;

  const ComingSoonPlaceholder({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
