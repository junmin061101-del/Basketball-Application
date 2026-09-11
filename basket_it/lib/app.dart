import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/onboarding/splash_screen.dart';

class BasketItApp extends StatelessWidget {
  /// main()에서 Firebase.initializeApp()이 성공했는지 여부.
  ///
  /// false면(테스트 환경, 또는 flutterfire configure를 아직 안 한 상태)
  /// Firebase를 전혀 건드리지 않고 온보딩 화면부터 시작한다.
  final bool firebaseReady;

  const BasketItApp({super.key, this.firebaseReady = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Basket it',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,
      // 한국 사용자용 앱이다. 날짜 선택기 같은 기본 위젯 문구("Sep 14" 등)도
      // 한국어로 나오게 한다.
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: firebaseReady ? const AuthGate() : const SplashScreen(),
    );
  }
}
