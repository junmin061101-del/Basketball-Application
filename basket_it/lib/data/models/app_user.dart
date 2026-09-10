import 'package:flutter/foundation.dart';

/// 앱 전역에서 사용하는 로그인 사용자 정보.
///
/// firebase_auth의 `User` 타입을 앱 나머지 부분에 직접 노출하지 않고
/// 이 타입으로 감싸서, 나중에 인증 수단이 바뀌어도 UI/Provider가
/// 영향받지 않도록 한다.
@immutable
class AppUser {
  final String uid;
  final String? email;

  /// 게스트(익명) 로그인 여부.
  final bool isAnonymous;

  const AppUser({required this.uid, this.email, this.isAnonymous = false});

  /// 승부예측 토론/랭킹에 표시할 이름. 게스트는 "게스트-xxxx".
  String get displayName {
    if (isAnonymous || email == null || email!.isEmpty) {
      return '게스트-${uid.substring(0, uid.length < 4 ? uid.length : 4)}';
    }
    return email!.split('@').first;
  }
}
