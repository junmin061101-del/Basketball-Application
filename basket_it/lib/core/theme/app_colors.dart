import 'package:flutter/material.dart';

/// NBA 공식 앱 스타일의 라이트 팔레트.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F7F9);
  static const Color surfaceElevated = Color(0xFFECEDF0);
  static const Color border = Color(0xFFE1E2E7);

  static const Color primary = Color(0xFFE8472B); // KBL 포인트 레드
  static const Color accent = Color(0xFFC98A00); // 강조용 골드(라이트 배경 대비용)

  static const Color textPrimary = Color(0xFF15161A);
  static const Color textSecondary = Color(0xFF5B5F68);
  static const Color textTertiary = Color(0xFF9A9DA6);

  static const Color live = Color(0xFFE0311F);
  static const Color positive = Color(0xFF1F9254);
  static const Color negative = Color(0xFFD8362A);

  /// 선수 상세 화면 히어로 배너처럼, 테마와 무관하게 항상 어둡게 유지해야
  /// 하는 영역(흰 글자 대비 확보)에 쓰는 고정 다크 톤.
  static const Color heroDark = Color(0xFF14161A);
}
