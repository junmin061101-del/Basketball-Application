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
              const AppLogo(),
              const SizedBox(height: 24),
              Text(
                'Baskit',
                style: Theme.of(context).textTheme.headlineLarge
                    ?.copyWith(fontSize: 36),
              ),
              const SizedBox(height: 8),
              Text(
                'KBL 팬을 위한 단 하나의 앱',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoadingScreen()),
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

/// 앱 로고(주황 둥근 네모 + 농구공). 시작 화면과 켜질 때 로딩 화면이 함께 쓴다.
/// web/index.html의 첫 로딩 화면도 같은 크기·모양이라 넘어갈 때 튀지 않는다.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    // 앱 아이콘과 같은 로고(assets/brand/app-logo.png). 흰 화면에서도 보이게
    // 옅은 그림자를 준다.
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C2B4E).withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Image.asset(
        'assets/brand/app-logo.png',
        width: 120,
        height: 120,
        semanticLabel: 'Baskit',
      ),
    );
  }
}
