import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/update/update_gate.dart';

/// 맨 아래 Navigator. 웹 뒤로 가기가 닫을 화면이 있는지 볼 때 쓴다.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class BasketItApp extends StatefulWidget {
  /// main()에서 Firebase.initializeApp()이 성공했는지 여부.
  ///
  /// false면(테스트 환경, 또는 flutterfire configure를 아직 안 한 상태)
  /// Firebase를 전혀 건드리지 않고 온보딩 화면부터 시작한다.
  final bool firebaseReady;

  const BasketItApp({super.key, this.firebaseReady = false});

  @override
  State<BasketItApp> createState() => _BasketItAppState();
}

class _BasketItAppState extends State<BasketItApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // MaterialApp보다 먼저 등록해야 뒤로 가기를 먼저 받는다.
    if (kIsWeb) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 웹(홈 화면에 올린 앱 포함)에서 손가락으로 밀어 뒤로 가면 브라우저의 뒤로
  /// 가기가 온다. 닫을 화면이 없을 때 Flutter는 "앱 종료"로 브라우저 기록을
  /// 거슬러 앱 밖으로 나가 버려, 앱을 처음부터 다시 불러왔다(긴 로딩 화면).
  /// 웹에서는 닫을 화면이 없으면 뒤로 가기를 무시한다. 닫을 화면이 있으면
  /// false를 돌려 MaterialApp이 평소대로 닫게 둔다. 빠르게 여러 번 밀 때는
  /// web/index.html이 깔아 둔 여분 기록이 앱 밖으로 나가는 걸 막는다.
  @override
  Future<bool> didPopRoute() async =>
      !(rootNavigatorKey.currentState?.canPop() ?? false);

  @override
  Widget build(BuildContext context) {
    final firebaseReady = widget.firebaseReady;
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Baskit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.light,
      // 한국 사용자용 앱이다. 날짜 선택기 같은 기본 위젯 문구("Sep 14" 등)도
      // 한국어로 나오게 한다.
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      scrollBehavior: const AppScrollBehavior(),
      // PC 브라우저에서는 화면이 넓어 내용이 가로로 늘어지고, 기록표처럼 폭이
      // 정해진 것 옆에 빈 공간만 남는다. 휴대폰 너비로 모아 가운데에 둔다.
      builder: (context, child) =>
          _PhoneWidth(child: child ?? const SizedBox.shrink()),
      home: firebaseReady
          ? const UpdateGate(child: AuthGate())
          : const SplashScreen(),
    );
  }
}

/// 넓은 화면에서는 앱을 휴대폰 너비로 가운데에 모은다.
///
/// 이 앱의 화면은 모두 휴대폰 폭(390 안팎)에 맞춰 만들었다. PC 브라우저에서
/// 그대로 늘리면 글씨만 양끝으로 흩어지고 표 옆이 비어 보여서, 바깥은 회색
/// 바탕으로 두고 가운데만 앱으로 쓴다. 창이 좁으면(휴대폰) 아무것도 바꾸지 않는다.
class _PhoneWidth extends StatelessWidget {
  final Widget child;

  /// 휴대폰 화면보다 조금 넉넉하게. 기록표는 이 안에서 가로로 스크롤한다.
  static const maxWidth = 520.0;

  const _PhoneWidth({required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth) return child;
    return ColoredBox(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Container(
          width: maxWidth,
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border.symmetric(
              vertical: BorderSide(color: AppColors.border),
            ),
          ),
          clipBehavior: Clip.hardEdge,
          // 안쪽 화면들이 창 전체가 아니라 이 폭을 기준으로 재도록 바꿔 준다.
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 마우스로 끌어서도 스크롤되게 한다.
///
/// 기록표와 칩 줄은 가로로 넘쳐서 밀어 봐야 나머지가 보인다. 휴대폰에서는
/// 손가락으로 밀면 되지만, PC 브라우저의 기본 설정은 마우스 끌기를 스크롤로
/// 보지 않아 뒷부분을 볼 방법이 없었다. 가로로 넘치는 곳에는 스크롤 막대도
/// 함께 보여 더 볼 것이 있다는 걸 알린다.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    final horizontal =
        details.direction == AxisDirection.left ||
        details.direction == AxisDirection.right;
    if (horizontal && kIsWeb) {
      return Scrollbar(controller: details.controller, child: child);
    }
    return super.buildScrollbar(context, child, details);
  }
}
