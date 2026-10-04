import 'package:basket_it/core/utils/nickname.dart';
import 'package:basket_it/providers/profile_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('닉네임 규칙', () {
    test('한글·영문·숫자·밑줄 2~10자는 쓸 수 있다', () {
      for (final name in ['농구왕', 'sk_fan', '워니팬22', '가나', '열글자꽉채운닉네임임']) {
        expect(nicknameError(name), isNull, reason: name);
      }
    });

    test('너무 짧거나 길면 막는다', () {
      expect(nicknameError('짧'), contains('2자'));
      expect(nicknameError('열글자를넘겨버린닉네임'), contains('10자'));
      expect(nicknameError('   '), contains('입력'));
    });

    test('띄어쓰기와 특수문자는 받지 않는다', () {
      expect(nicknameError('농구 왕'), contains('한글'));
      expect(nicknameError('농구왕!'), contains('한글'));
      expect(nicknameError('@sk'), contains('한글'));
    });

    test('앱이 쓰는 이름은 가로챌 수 없다', () {
      expect(nicknameError('게스트1234'), isNotNull);
      expect(nicknameError('관리자'), isNotNull);
      expect(nicknameError('ADMIN'), isNotNull);
      expect(nicknameError('탈퇴한 사용자'), isNotNull);
    });

    test('앞뒤 공백은 떼어 내고 센다', () {
      expect(nicknameError('  농구왕  '), isNull);
      expect(normalizeNickname('  농구왕  '), '농구왕');
      expect(isValidNickname(' 농구왕 '), isTrue);
    });
  });

  group('글에 남길 이름', () {
    test('닉네임을 정했으면 그대로 쓴다', () {
      expect(
        resolveDisplayName(nickname: '농구왕', fallback: 'junmin@example.com'),
        '농구왕',
      );
    });

    test('닉네임이 없으면 이메일에서 만든 이름을 가린다', () {
      expect(
        resolveDisplayName(nickname: null, fallback: 'junmin'),
        'j****n',
      );
      expect(resolveDisplayName(nickname: '  ', fallback: 'junmin'), 'j****n');
    });

    test('게스트 이름은 그대로 둔다', () {
      expect(
        resolveDisplayName(nickname: null, fallback: '게스트-ab12'),
        '게스트-ab12',
      );
    });
  });
}
