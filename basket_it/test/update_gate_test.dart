import 'package:basket_it/features/update/update_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('minBuild보다 낮은 빌드만 막는다. 설정이 없거나 이상하면 막지 않는다', () {
    expect(needsUpdate(3, {'minBuild': 5}), isTrue);
    expect(needsUpdate(5, {'minBuild': 5}), isFalse);
    expect(needsUpdate(9, {'minBuild': 5}), isFalse);
    expect(needsUpdate(1, null), isFalse);
    expect(needsUpdate(1, {'minBuild': '5'}), isFalse);
  });
}
