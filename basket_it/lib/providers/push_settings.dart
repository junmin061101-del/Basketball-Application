import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 잠금화면 실시간 스코어 알림을 받을지. 기기마다 따로 기억한다.
///
/// 끄면 구독 문서의 팀 목록을 비우므로(main_shell이 반영한다) 서버가 이 기기를
/// 찾지 못해 아무것도 보내지 않는다. 기본값은 켜짐이다.
final livePushEnabledProvider =
    AsyncNotifierProvider<LivePushEnabled, bool>(LivePushEnabled.new);

class LivePushEnabled extends AsyncNotifier<bool> {
  static const _key = 'live_score_push_enabled';
  static const _storage = FlutterSecureStorage();

  @override
  Future<bool> build() async {
    try {
      return await _storage.read(key: _key) != 'off';
    } catch (_) {
      // 저장소를 못 읽는 환경(테스트·웹 일부)에서는 켜진 것으로 본다.
      return true;
    }
  }

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    try {
      await _storage.write(key: _key, value: enabled ? 'on' : 'off');
    } catch (_) {
      // 저장에 실패해도 이번 실행 동안은 고른 값을 따른다.
    }
  }
}
