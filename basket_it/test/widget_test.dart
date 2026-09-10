import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:basket_it/app.dart';

void main() {
  testWidgets('스플래시 화면에 시작하기 버튼이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BasketItApp()));

    expect(find.text('Basket it'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });
}
