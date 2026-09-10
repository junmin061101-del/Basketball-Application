import 'package:flutter/foundation.dart';

/// 선수 신상 정보 (프로필 헤더에 표시).
///
/// 원본이 모르는 값은 지어내지 않는다. 키·몸무게는 0, 생년월일은 null,
/// 문자열은 빈 값으로 두고 화면에는 '-'로 보인다.
@immutable
class PlayerBio {
  /// 0이면 모름.
  final int heightCm;

  /// 0이면 모름.
  final int weightKg;
  final DateTime? birthDate;
  final String country;
  final String college;
  final int draftYear;
  final int draftRound;
  final int draftPick;

  /// [country]가 국적이 아니라 출생 국가인지.
  ///
  /// 국적 정보가 없어 출생 국가로 대신한 경우다. 출생지와 국적이 다른 선수가
  /// 있으므로(카이리 어빙은 호주 출생·미국 국적) 칸 이름을 바꿔 적는다.
  final bool countryIsBirthplace;

  const PlayerBio({
    required this.heightCm,
    required this.weightKg,
    required this.birthDate,
    required this.country,
    required this.college,
    required this.draftYear,
    required this.draftRound,
    required this.draftPick,
    this.countryIsBirthplace = false,
  });

  /// 신상을 하나도 모를 때. KBL 홈페이지는 신상을 주지 않는다.
  const PlayerBio.unknown()
    : heightCm = 0,
      weightKg = 0,
      birthDate = null,
      country = '',
      college = '',
      draftYear = draftUnknown,
      draftRound = 0,
      draftPick = 0,
      countryIsBirthplace = false;

  /// 보여줄 값이 하나도 없는지. 전부 '-'인 칸을 늘어놓지 않으려고 쓴다.
  bool get isEmpty =>
      heightCm <= 0 &&
      weightKg <= 0 &&
      birthDate == null &&
      country.trim().isEmpty &&
      college.trim().isEmpty &&
      draftYear == draftUnknown;

  /// 만 나이. 생년월일을 모르면 null.
  int? ageAt(DateTime now) {
    final birth = birthDate;
    if (birth == null) return null;
    var age = now.year - birth.year;
    final beforeBirthdayThisYear =
        now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day);
    if (beforeBirthdayThisYear) age -= 1;
    return age;
  }

  String get heightLabel =>
      heightCm <= 0 ? '-' : '${(heightCm / 100).toStringAsFixed(2)}m';

  String get weightLabel => weightKg <= 0 ? '-' : '${weightKg}kg';

  /// 값이 없을 때 빈칸 대신 '-'. 고졸 선수는 출신 대학이 없다.
  String get collegeLabel => college.trim().isEmpty ? '-' : college;

  /// 값이 없을 때 빈칸 대신 '-'.
  String get countryLabel => country.trim().isEmpty ? '-' : country;

  /// 국적 칸의 이름. 출생 국가로 대신했으면 '출생국'이라고 적는다.
  String get countryTitle => countryIsBirthplace ? '출생국' : '국적';

  String get birthLabel {
    final birth = birthDate;
    if (birth == null) return '-';
    return '${birth.year}.${birth.month.toString().padLeft(2, '0')}.${birth.day.toString().padLeft(2, '0')}';
  }

  /// "1998.09.02 (28세)". 생년월일을 모르면 '-'.
  String birthWithAgeLabel(DateTime now) {
    final age = ageAt(now);
    return age == null ? '-' : '$birthLabel ($age세)';
  }

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
