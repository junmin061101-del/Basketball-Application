import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 탭 맨 위의 제목 줄. 왼쪽에 굵은 제목, 오른쪽에 리그 전환 같은 버튼을 둔다.
class PageHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const PageHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.1,
                letterSpacing: -0.8,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
