import 'package:basket_it/core/utils/nickname.dart';
import 'package:basket_it/core/utils/profanity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('욕설은 띄어 쓰거나 기호를 끼워도 잡는다', () {
    expect(containsProfanity('이 씨발 경기'), isTrue);
    expect(containsProfanity('씨 . 발'), isTrue);
    expect(containsProfanity('ㅂ ㅅ 같은 수비'), isTrue);
    expect(containsProfanity('What the FUCK'), isTrue);
  });

  test('평범한 농구 이야기는 막지 않는다', () {
    expect(containsProfanity('역전의 시발점은 3쿼터였다'), isFalse);
    expect(containsProfanity('패배를 곱씹으며'), isFalse);
    expect(containsProfanity('허웅 3점슛 미쳤다'), isFalse);
    expect(containsProfanity('새끼손가락 부상으로 결장'), isFalse);
    expect(containsProfanity('개막전 승리! 정관장 화이팅'), isFalse);
    expect(containsProfanity('수비 리바운드 장악'), isFalse);
  });

  test('닉네임도 막는다', () {
    expect(nicknameError('병신123'), isNotNull);
    expect(nicknameError('농구왕'), isNull);
  });
}
