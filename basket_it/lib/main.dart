import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseReady = true;
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
