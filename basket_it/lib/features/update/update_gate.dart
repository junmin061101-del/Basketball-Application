import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../onboarding/splash_screen.dart';

/// 강제 업데이트. 지금 앱이 너무 오래됐으면 업데이트 화면으로 막는다.
///
/// Firestore `appConfig/release` 문서(콘솔에서 운영자가 고친다):
///   minBuild:   이 빌드 번호(pubspec version의 + 뒤 숫자)보다 낮으면 막는다
///   message:    화면에 보여줄 안내(없으면 기본 문구)
///   androidUrl / iosUrl: 스토어 주소
///
/// 출시한 뒤에는 이미 깔린 앱에 이 장치를 넣을 수 없어서 첫 버전부터 둔다.
/// 웹은 항상 최신이라 보지 않는다. 문서를 못 읽으면(오프라인 등) 막지 않는다.
class UpdateGate extends StatefulWidget {
  final Widget child;

  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  late final Future<Map<String, Object?>?> _required = _check();

  static Future<Map<String, Object?>?> _check() async {
    if (kIsWeb) return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final doc = await FirebaseFirestore.instance
          .doc('appConfig/release')
          .get()
          .timeout(const Duration(seconds: 5));
      final config = doc.data();
      return needsUpdate(int.tryParse(info.buildNumber) ?? 0, config)
          ? config
          : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _required,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: AppLogo()));
        }
        final config = snapshot.data;
        return config == null ? widget.child : _UpdateRequired(config: config);
      },
    );
  }
}

/// 지금 빌드가 [config]의 minBuild보다 낮은지.
bool needsUpdate(int currentBuild, Map<String, Object?>? config) {
  final min = config?['minBuild'];
  return min is num && currentBuild < min;
}

class _UpdateRequired extends StatelessWidget {
  final Map<String, Object?> config;

  const _UpdateRequired({required this.config});

  @override
  Widget build(BuildContext context) {
    final url =
        config[defaultTargetPlatform == TargetPlatform.iOS
                ? 'iosUrl'
                : 'androidUrl']
            as String?;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const AppLogo(),
              const SizedBox(height: 28),
              Text(
                '새 버전이 나왔어요',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                config['message'] as String? ?? '계속 쓰려면 앱을 업데이트해 주세요.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(flex: 4),
              if (url != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('업데이트하기'),
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
