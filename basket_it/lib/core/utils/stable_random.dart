import 'dart:math';

/// 플랫폼과 무관하게 항상 같은 수열을 만드는 난수 생성기.
///
/// `dart:math`의 [Random]은 같은 시드를 줘도 Dart VM과 웹(dart2js)에서
/// 다른 수열을 만든다. 목업 데이터가 "어디서 보든 같은 경기 = 같은 기록"이
/// 되려면 이게 문제가 되므로, 정수 연산만으로 정의된 Lehmer(Park-Miller)
/// 생성기를 직접 쓴다. 모든 곱셈이 double의 정확 표현 범위(2^53) 안이라
/// VM/JS/AOT 어디서든 결과가 같다.
class StableRandom implements Random {
  static const int _modulus = 2147483647; // 2^31 - 1
  static const int _multiplier = 48271;

  int _state;

  StableRandom(int seed) : _state = _normalizeSeed(seed);

  static int _normalizeSeed(int seed) {
    final s = seed.abs() % _modulus;
    return s == 0 ? 1 : s;
  }

  int _next() => _state = (_state * _multiplier) % _modulus;

  @override
  int nextInt(int max) {
    if (max <= 0) throw RangeError.range(max, 1, null, 'max');
    return _next() % max;
  }

  @override
  double nextDouble() => (_next() - 1) / (_modulus - 1);

  @override
  bool nextBool() => _next().isEven;
}
