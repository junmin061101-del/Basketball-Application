import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
    if (!kIsWeb) await _setUpCrashlytics();
    await _setUpAppCheck();
  } catch (e) {
    // firebase_options.dart가 아직 플레이스홀더 상태이거나(flutterfire configure
    // 미실행), 네트워크 문제 등으로 초기화에 실패한 경우. 온보딩 화면까지는
    // Firebase 없이도 볼 수 있도록 앱은 계속 실행한다.
    debugPrint(
      'Firebase 초기화 실패: $e\n'
      '`flutterfire configure`를 실행했는지 확인해주세요.',
    );
  }

  runApp(ProviderScope(child: BasketItApp(firebaseReady: firebaseReady)));
}

/// 웹 App Check용 reCAPTCHA Enterprise 사이트 키. 사이트 키는 웹페이지에
/// 공개되는 값이다(비밀 키가 아니다). 허용 도메인은 reCAPTCHA 콘솔에서 정한다.
const _recaptchaSiteKey = '6Lfqgh8uAAAAAJBozuNtCHZ2wRA9GeytLhNXqOhg';

/// 휴대폰 앱의 크래시를 Crashlytics로 보낸다(웹은 지원하지 않는다).
Future<void> _setUpCrashlytics() async {
  // 크래시를 Crashlytics로 보낸다. 개발 중(debug)에는 보내지 않는다.
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}

/// 정품 앱(웹·Android·iOS)에서 온 요청인지 Firebase가 확인하게 한다. 콘솔에서
/// "적용"을 켜기 전까지는 확인만 하고 막지는 않는다. debug 빌드는 콘솔에 등록한
/// 디버그 토큰을 쓴다.
Future<void> _setUpAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaEnterpriseProvider(_recaptchaSiteKey),
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (e, stack) {
    // App Check가 안 켜져도 앱은 쓸 수 있어야 한다(콘솔에서 적용을 켜기 전까지).
    if (kIsWeb) {
      debugPrint('App Check 시작 실패: $e');
    } else {
      FirebaseCrashlytics.instance.recordError(e, stack);
    }
  }
}
