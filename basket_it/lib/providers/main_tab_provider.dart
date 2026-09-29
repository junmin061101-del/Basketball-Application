import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 지금 보고 있는 하단 탭(0=홈, 1=경기, 2=예측, 3=커뮤니티, 4=탐색).
///
/// 탐색 화면의 "오늘의 실시간 경기 예측" 배너처럼, 다른 탭으로 보내야 하는
/// 곳에서 이 값을 바꾼다.
final mainTabIndexProvider = StateProvider<int>((ref) => 0);
