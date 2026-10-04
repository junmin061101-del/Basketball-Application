import 'package:flutter/foundation.dart';

/// 앱이 보여주는 약관 문서.
///
/// 본문은 `assets/legal/*.md`에 마크다운으로 두고 화면이 읽어 그린다. 문서를
/// 고칠 일이 생기면 그 파일만 고치면 되고, 같은 파일을 웹에도 그대로 올릴 수 있다.
@immutable
class PolicyDocument {
  /// 화면 제목이자 바닥글에 적는 이름.
  final String title;

  /// 앱에 담긴 마크다운 파일 경로.
  final String assetPath;

  const PolicyDocument({required this.title, required this.assetPath});
}

const termsOfService = PolicyDocument(
  title: '이용약관',
  assetPath: 'assets/legal/terms_of_service.md',
);

const privacyPolicy = PolicyDocument(
  title: '개인정보처리방침',
  assetPath: 'assets/legal/privacy_policy.md',
);

/// 운영자 문의처. 바닥글과 약관 화면이 같은 값을 쓴다.
const contactEmail = 'junmin061101@gmail.com';
