import 'package:basket_it/core/utils/name_mask.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('일반 이름은 가운데를 가린다', () {
    expect(maskDisplayName('강민수'), '강*수');
    expect(maskDisplayName('김도윤'), '김*윤');
    expect(maskDisplayName('남궁민수'), '남**수');
  });

  test('두 글자 이름은 뒤를 가린다', () {
    expect(maskDisplayName('이하'), '이*');
  });

  test('한 글자와 빈 값 처리', () {
    expect(maskDisplayName('강'), '강');
    expect(maskDisplayName('   '), '익명');
  });

  test('이메일은 아이디만 남기고 가린다', () {
    expect(maskDisplayName('minsu@example.com'), 'm***u');
  });

  test('게스트 식별자는 그대로 둔다', () {
    expect(maskDisplayName('게스트-rU6R'), '게스트-rU6R');
  });
}
