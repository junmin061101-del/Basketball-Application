import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'loading_screen.dart';

/// 앱 최초 실행 시 보여지는 시작 화면.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              // 임시 로고 플레이스홀더
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_basketball,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Basket it',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 36,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'KBL 팬을 위한 단 하나의 앱',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoadingScreen(),
                      ),
                    );
                  },
                  child: const Text('시작하기'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
