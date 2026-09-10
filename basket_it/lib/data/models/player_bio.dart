import 'package:flutter/foundation.dart';

/// 선수 신상 정보 (프로필 헤더에 표시).
@immutable
class PlayerBio {
  final int heightCm;
  final int weightKg;
  final DateTime birthDate;
  final String country;
  final String college;
  final int draftYear;
  final int draftRound;
  final int draftPick;

  const PlayerBio({
    required this.heightCm,
    required this.weightKg,
    required this.birthDate,
    required this.country,
    required this.college,
    required this.draftYear,
    required this.draftRound,
    required this.draftPick,
  });

  int ageAt(DateTime now) {
    var age = now.year - birthDate.year;
    final beforeBirthdayThisYear =
        now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day);
    if (beforeBirthdayThisYear) age -= 1;
    return age;
  }

  String get heightLabel => '${(heightCm / 100).toStringAsFixed(2)}m';

  String get birthLabel =>
      '${birthDate.year}.${birthDate.month.toString().padLeft(2, '0')}.${birthDate.day.toString().padLeft(2, '0')}';

  /// 드래프트 정보를 아직 모를 때 [draftYear]에 넣는 값.
  ///
  /// 조회에 실패한 선수를 "미지명"이라고 적으면 틀린 정보가 된다.
  /// 모르는 것과 뽑히지 않은 것을 구분한다.
  static const draftUnknown = -1;

  /// 드래프트에 뽑히지 않은 선수는 연도가 0으로 온다.
  bool get isUndrafted => draftYear == 0;

  String get draftLabel {
    if (draftYear < 0) return '-';
    if (isUndrafted) return '미지명';
    return '$draftYear년 $draftRound라운드 $draftPick순위';
  }
}
