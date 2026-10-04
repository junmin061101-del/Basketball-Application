import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'policy_detail_screen.dart';
import 'policy_documents.dart';

/// 화면 맨 아래에 두는 약관 바닥글.
///
/// 목록을 끝까지 내리면 나오고, 누르면 전문을 볼 수 있다.
class LegalFooter extends StatelessWidget {
  const LegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Column(
        children: [
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PolicyLink(document: termsOfService),
              Container(
                width: 1,
                height: 11,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: AppColors.border,
              ),
              _PolicyLink(document: privacyPolicy),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '문의: $contactEmail',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Baskit · KBL 팬을 위한 앱',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _PolicyLink extends StatelessWidget {
  final PolicyDocument document;

  const _PolicyLink({required this.document});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PolicyDetailScreen(document: document),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Text(
          document.title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
