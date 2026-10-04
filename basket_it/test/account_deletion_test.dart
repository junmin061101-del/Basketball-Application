import 'package:basket_it/providers/account_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('탈퇴한 사람의 글은 지우지 않고 글쓴이만 지운다', () {
    // 보안 규칙(firestore.rules의 anonymizingOwn)이 이 두 값만 허용한다.
    expect(anonymousUid, 'deleted');
    expect(anonymousName, '탈퇴한 사용자');
  });
}
