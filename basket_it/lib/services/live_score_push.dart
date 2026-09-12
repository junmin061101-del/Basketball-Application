import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/activity_update.dart';

/// 서버(functions/live-score.js)가 구독 기기를 찾는 팀 키.
/// NBA 팀 id는 ESPN 숫자("13"), KBL 팀 id는 영문("sk")이라 모양으로 리그를 가른다.
Set<String> liveTeamKeys(Iterable<String> teamIds) {
  final digits = RegExp(r'^\d+$');
  return {
    for (final id in teamIds)
      if (id.isNotEmpty) digits.hasMatch(id) ? 'nba:$id' : 'kbl:$id',
  };
}

/// liveSubscribers/{fcmToken} 문서에 [fields]를 쓴다. [fields]에 든 필드만 통째로 바꾼다.
typedef LiveSubscriberWrite = Future<void> Function(
  String fcmToken,
  Map<String, Object?> fields,
);

/// 잠금화면 스코어 구독 문서에 무엇을 언제 쓸지 정한다.
///
/// FCM 토큰이 생기기 전에는 아무것도 쓰지 않고 값만 기억했다가, 토큰이 생기면
/// 한 번에 쓴다. 이미 쓴 값과 같으면 다시 쓰지 않는다.
class LiveScoreSubscription {
  LiveScoreSubscription({required this.platform, required this.write});

  /// 'android' 또는 'ios'.
  final String platform;
  final LiveSubscriberWrite write;

  String? _token;
  Set<String> _teamKeys = {};
  Set<String>? _writtenTeamKeys;
  String? _pushToStartToken;
  String? _writtenPushToStartToken;
  Map<String, String> _activityTokens = {};
  Map<String, String>? _writtenActivityTokens;

  Future<void> setFcmToken(String token) async {
    if (token.isEmpty || token == _token) return;
    _token = token;
    _writtenTeamKeys = null;
    _writtenPushToStartToken = null;
    _writtenActivityTokens = null;
    await _flush();
  }

  Future<void> setTeams(Iterable<String> teamIds) async {
    _teamKeys = liveTeamKeys(teamIds);
    await _flush();
  }

  /// iPhone(iOS 17.2+)에서 서버가 Live Activity를 새로 띄울 때 쓰는 토큰.
  Future<void> setPushToStartToken(String token) async {
    if (token.isEmpty) return;
    _pushToStartToken = token;
    await _flush();
  }

  /// 지금 떠 있는 Live Activity들의 갱신 토큰. 키는 활동의 attributes.id(소문자 UUID)로,
  /// 서버가 경기 키로 만든 UUID와 같다. 끝난 활동은 빠진 채로 통째로 바꾼다.
  Future<void> setActivityTokens(Map<String, String> tokens) async {
    _activityTokens = {
      for (final e in tokens.entries) e.key.toLowerCase(): e.value,
    };
    await _flush();
  }

  Future<void> _flush() async {
    final token = _token;
    if (token == null) return;
    final fields = <String, Object?>{};
    if (!setEquals(_teamKeys, _writtenTeamKeys)) {
      fields['teamKeys'] = _teamKeys.toList()..sort();
    }
    if (_pushToStartToken != null &&
        _pushToStartToken != _writtenPushToStartToken) {
      fields['pushToStartToken'] = _pushToStartToken;
    }
    if (platform == 'ios' &&
        !mapEquals(_activityTokens, _writtenActivityTokens)) {
      fields['activityTokens'] = Map<String, String>.of(_activityTokens);
    }
    if (fields.isEmpty) return;

    final teamKeys = _teamKeys;
    final pushToStart = _pushToStartToken;
    final activityTokens = _activityTokens;
    await write(token, fields);
    if (fields.containsKey('teamKeys')) _writtenTeamKeys = teamKeys;
    if (fields.containsKey('pushToStartToken')) {
      _writtenPushToStartToken = pushToStart;
    }
    if (fields.containsKey('activityTokens')) {
      _writtenActivityTokens = activityTokens;
    }
  }
}

/// 기기와 Firebase를 잇는 부분. Android·iPhone 앱에서만 돈다(웹·테스트는 건너뜀).
class LiveScorePushService {
  LiveScorePushService._(this._subscription);

  static LiveScorePushService? _instance;

  /// iOS 앱과 위젯 확장이 함께 쓰는 App Group. Xcode에서 같은 이름으로 켜야 한다.
  static const appGroupId = 'group.com.basketit.basketIt.liveScore';

  /// AppDelegate.swift의 LiveActivityLink. 활동 id ↔ attributes.id를 알려준다.
  static const _link = MethodChannel('basketit/live_activity_link');

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// 로그인한 뒤 한 번 부른다. 여러 번 불러도 한 번만 시작한다.
  static LiveScorePushService? start() {
    if (!supported) return null;
    return _instance ??= LiveScorePushService._(
      LiveScoreSubscription(
        platform: _isIos ? 'ios' : 'android',
        write: _firestoreWrite,
      ),
    ).._begin();
  }

  final LiveScoreSubscription _subscription;
  final Map<String, String> _systemActivityTokens = {};
  Timer? _activitySync;

  /// 팔로우한 팀이 바뀔 때마다 부른다.
  void updateTeams(Iterable<String> teamIds) {
    _guard('팔로우 팀 저장', () => _subscription.setTeams(teamIds));
  }

  static Future<void> _firestoreWrite(
    String fcmToken,
    Map<String, Object?> fields,
  ) {
    final data = <String, Object?>{
      ...fields,
      'platform': _isIos ? 'ios' : 'android',
      'fcmToken': fcmToken,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return FirebaseFirestore.instance
        .collection('liveSubscribers')
        .doc(fcmToken)
        .set(data, SetOptions(mergeFields: data.keys.toList()));
  }

  void _begin() {
    _guard('실시간 스코어 시작', () async {
      final messaging = FirebaseMessaging.instance;
      // Android 13+의 알림 권한, iPhone의 알림 권한을 묻는다.
      await messaging.requestPermission();
      if (_isIos) await _beginIos();
      final token = await _fcmToken(messaging);
      if (token != null) await _subscription.setFcmToken(token);
      messaging.onTokenRefresh.listen(
        (t) => _guard('FCM 토큰 갱신', () => _subscription.setFcmToken(t)),
      );
    });
  }

  /// iPhone은 APNs 토큰이 먼저 나와야 FCM 토큰을 받을 수 있어 잠시 기다린다.
  Future<String?> _fcmToken(FirebaseMessaging messaging) async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        if (_isIos && await messaging.getAPNSToken() == null) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        return await messaging.getToken();
      } catch (e) {
        debugPrint('FCM 토큰을 아직 받지 못했습니다: $e');
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  Future<void> _beginIos() async {
    final liveActivities = LiveActivities();
    await liveActivities.init(appGroupId: appGroupId);
    liveActivities.pushToStartTokenUpdateStream.listen(
      (t) => _guard('시작 토큰 저장', () => _subscription.setPushToStartToken(t)),
    );
    liveActivities.activityUpdateStream.listen((update) {
      if (update is ActiveActivityUpdate) {
        _systemActivityTokens[update.activityId] = update.activityToken;
      } else if (update is EndedActivityUpdate) {
        _systemActivityTokens.remove(update.activityId);
      }
      // 앱이 켜질 때 떠 있는 활동의 토큰이 한꺼번에 오므로 모아서 한 번 쓴다.
      _activitySync?.cancel();
      _activitySync = Timer(const Duration(seconds: 1), () {
        _guard('활동 토큰 저장', _syncActivityTokens);
      });
    });
  }

  Future<void> _syncActivityTokens() async {
    final attributeIds =
        await _link.invokeMapMethod<String, String>('attributeIds') ?? {};
    await _subscription.setActivityTokens({
      for (final e in _systemActivityTokens.entries)
        if (attributeIds[e.key] != null) attributeIds[e.key]!: e.value,
    });
  }

  static void _guard(String label, Future<void> Function() action) {
    unawaited(
      action().catchError((Object e) {
        // 잠금화면 스코어가 안 되더라도 앱 사용은 막지 않는다.
        debugPrint('$label 실패: $e');
      }),
    );
  }
}
