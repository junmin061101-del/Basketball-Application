import 'package:basket_it/features/games/game_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('올해 경기는 월·일만, 지난 시즌 경기는 연도까지 보여준다', () {
    final now = DateTime(2026, 9, 12);
    expect(
      GameDetailScreen.dateTitle(DateTime(2026, 6, 18), now: now),
      '6월 18일',
    );
    expect(
      GameDetailScreen.dateTitle(DateTime(2024, 6, 18), now: now),
      '2024년 6월 18일',
    );
  });
}
