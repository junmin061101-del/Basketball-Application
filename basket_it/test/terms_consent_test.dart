import 'package:basket_it/features/onboarding/terms_consent_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('두 항목에 모두 동의해야 저장하고 넘어간다', (tester) async {
    var saved = 0;
    var done = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TermsConsentScreen(
          onAgree: () async => saved++,
          onDone: () => done++,
        ),
      ),
    );
    final button = find.widgetWithText(ElevatedButton, '동의하고 시작하기');
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

    await tester.tap(find.text('[필수] 이용약관 동의'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

    await tester.tap(find.text('[필수] 개인정보처리방침 동의'));
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect((saved, done), (1, 1));
  });
}
