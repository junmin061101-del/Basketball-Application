/// 실행 환경(Dart VM / 웹 JS / AOT)에 상관없이 항상 같은 값을 주는
/// 문자열 해시(FNV-1a 32비트).
///
/// Dart의 `String.hashCode`/`Object.hash`는 프로세스마다 시드가 달라지고,
/// 32비트 곱셈을 그대로 하면 웹(정수가 double)에서 2^53을 넘겨 정밀도를
/// 잃는다. 그래서 곱셈을 16비트로 쪼개 항상 정확한 범위 안에서 계산한다.
int stableHash(String value) {
  const prime = 0x01000193;
  var hash = 0x811c9dc5;
  for (var i = 0; i < value.length; i++) {
    hash = (hash ^ value.codeUnitAt(i)) & 0xFFFFFFFF;
    final low = (hash & 0xFFFF) * prime; // < 2^16 * 2^25 = 2^41
    final high = ((hash >> 16) * prime) & 0xFFFF;
    hash = ((high * 0x10000) + low) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// 여러 조각을 이어 붙여 만드는 안정적인 시드.
int stableSeed(List<Object> parts) => stableHash(parts.join('|'));
