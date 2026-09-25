import 'package:flutter/material.dart';

/// Baskit UI 디자인(Figma)에서 뽑은 색.
///
/// 값은 디자인 시안 이미지의 실제 픽셀에서 가져왔다. 화면마다 색을 새로 정하지
/// 말고 여기 있는 것만 쓴다.
class AppColors {
  AppColors._();

  /// 화면 바탕. 카드가 흰색이라 바탕도 흰색이고, 구분은 선과 옅은 회색으로 준다.
  static const Color background = Color(0xFFFFFFFF);

  /// 옅은 회색 면(표 머리줄, 비활성 칩 등).
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceElevated = Color(0xFFF1F5F9);

  /// 경기 카드처럼 종이 느낌을 주는 크림색 면.
  static const Color surfaceCream = Color(0xFFF6F5F2);

  static const Color border = Color(0xFFE5E7EB);

  /// 포인트 색(주요 버튼·링크·선택 표시).
  static const Color primary = Color(0xFFF97316);

  /// 선택한 날짜처럼 주황을 옅게 깔 때.
  static const Color primarySoft = Color(0xFFFFE8D4);

  /// 숫자 강조와 비교 막대 오른쪽.
  static const Color accent = Color(0xFF3B82F6);
  static const Color accentSoft = Color(0xFFEFF6FF);

  /// 어두운 카드(최고 활약)와 그 위의 강조색.
  static const Color dark = Color(0xFF172033);
  static const Color sky = Color(0xFF38BDF8);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  static const Color live = Color(0xFFEF4444);
  static const Color positive = Color(0xFF10B981);
  static const Color positiveSoft = Color(0xFFD1FAE5);
  static const Color negative = Color(0xFFEF4444);
  static const Color negativeSoft = Color(0xFFFEE2E2);

  /// 선수 상세 히어로처럼 항상 어두워야 하는 영역.
  static const Color heroDark = Color(0xFF111827);
}
