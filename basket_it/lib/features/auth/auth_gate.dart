import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../onboarding/login_screen.dart';
import '../onboarding/splash_screen.dart';

/// 앱을 켤 때 어느 화면부터 보여줄지 결정한다.
///
/// - 처음 쓰는 사용자: 스플래시 → 온보딩(팀/선수 팔로우) → 로그인
/// - 한 번이라도 로그인한 적 있는 사용자: 온보딩을 건너뛰고 곧장 로그인 화면.
///   아이디·비밀번호가 저장돼 있으면 이미 채워져 있어 버튼만 누르면 들어간다.
///
/// 로그인 세션이 남아 있어도 로그인 화면은 항상 한 번 거치도록 한다.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedCredentialProvider);
    final authState = ref.watch(authStateProvider);

    // 저장된 자격증명 확인이 끝날 때까지 잠깐 로딩.
    if (savedAsync.isLoading || authState.isLoading) return const _GateLoading();

    final hasSavedCredential = savedAsync.valueOrNull != null;
    final hasSession = authState.valueOrNull != null;

    if (hasSavedCredential || hasSession) return const LoginScreen();
    return const SplashScreen();
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}
