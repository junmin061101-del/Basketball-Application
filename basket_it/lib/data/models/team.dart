import 'package:flutter/material.dart';

/// KBL 구단 정보.
///
/// [logoAsset]은 아직 실제 로고 리소스가 없어 null이며, UI에서는
/// [TeamLogoPlaceholder] 위젯이 [primaryColor] + [shortName]으로 대체 표시한다.
@immutable
class Team {
  final String id;
  final String city;
  final String name;
  final String shortName;
  final Color primaryColor;
  final String? logoAsset;

  /// 원격 엠블럼 이미지. NBA는 ESPN이 주는 공식 로고, KBL은 아직 없다.
  final String? logoUrl;

  const Team({
    required this.id,
    required this.city,
    required this.name,
    required this.shortName,
    required this.primaryColor,
    this.logoAsset,
    this.logoUrl,
  });

  /// "서울 SK" 형태의 전체 명칭.
  String get fullName => '$city $name';

  @override
  bool operator ==(Object other) => other is Team && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
