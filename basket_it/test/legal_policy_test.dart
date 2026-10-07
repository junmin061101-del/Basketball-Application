import 'dart:io';

import 'package:basket_it/core/theme/app_theme.dart';
import 'package:basket_it/features/legal/legal_footer.dart';
import 'package:basket_it/features/legal/policy_detail_screen.dart';
import 'package:basket_it/features/legal/policy_documents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// 문서를 다 읽을 때까지 몇 프레임 돌린다.
  /// (불러오는 동안 도는 동그라미 때문에 pumpAndSettle은 끝나지 않는다)
  Future<void> settleDocument(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('바닥글의 약관을 누르면 전문이 열린다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: SingleChildScrollView(child: LegalFooter())),
      ),
    );

    expect(find.text('이용약관'), findsOneWidget);
    expect(find.text('개인정보처리방침'), findsOneWidget);
    expect(find.text('문의: $contactEmail'), findsOneWidget);

    await tester.tap(find.text('이용약관'));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    await settleDocument(tester);

    // 제목(앱바)과 본문이 함께 보인다.
    expect(find.text('이용약관'), findsWidgets);
    expect(find.textContaining('제1조 (목적)'), findsOneWidget);
  });

  testWidgets('개인정보처리방침도 같은 화면으로 열린다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PolicyDetailScreen(document: privacyPolicy)),
    );
    await settleDocument(tester);

    expect(find.text('개인정보처리방침'), findsWidgets);
    expect(find.textContaining('수집하는 개인정보 항목'), findsOneWidget);
  });

  test('약관 문서에는 빠지면 안 되는 내용이 들어 있다', () {
    final terms = File(termsOfService.assetPath).readAsStringSync();
    final privacy = File(privacyPolicy.assetPath).readAsStringSync();

    for (final doc in [terms, privacy]) {
      expect(doc, contains('Baskit'));
      expect(doc, contains('이준민'));
      expect(doc, contains(contactEmail));
      expect(doc, contains('2026년 10월 4일'));
    }
    // 약관: 금지행위·게시물 관리·면책·관할
    expect(terms, contains('금지행위'));
    // KBL이 내려 달라고 하면 바로 멈춘다는 약속이 빠지면 안 된다.
    expect(terms, contains('KBL이 기록·사진·엠블럼의 이용을 중단해 달라고 요청하면'));
    expect(terms, contains('24시간 이내'));
    expect(terms, contains('관할법원'));
    // 처리방침: 국외 이전(Firebase)·보유 기간·권리 행사·보호책임자
    expect(privacy, contains('Google LLC'));
    expect(privacy, contains('국외'));
    expect(privacy, contains('탈퇴'));
    expect(privacy, contains('개인정보 보호책임자'));
  });

  test('마크다운은 제목·목록·굵은 글씨·링크를 블록으로 나눈다', () {
    final blocks = markdownBlocks(
      '# 제목\n\n'
      '## 작은 제목\n\n'
      '- 첫째 **중요**\n'
      '1. 번호 [링크](https://example.com)\n\n'
      '그냥 문단',
    );
    expect(blocks, hasLength(5));
  });
}
