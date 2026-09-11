import 'package:basket_it/core/theme/app_theme.dart';
import 'package:basket_it/data/models/game.dart';
import 'package:basket_it/data/models/team.dart';
import 'package:basket_it/features/games/games_tab.dart';
import 'package:basket_it/providers/game_providers.dart';
import 'package:basket_it/providers/repository_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_repositories.dart';

const teams = [
  Team(
    id: '2',
    city: '보스턴',
    name: '셀틱스',
    shortName: '보스턴',
    primaryColor: Color(0xFF008348),
  ),
  Team(
    id: '8',
    city: '디트로이트',
    name: '피스톤스',
    shortName: '디트로이트',
    primaryColor: Color(0xFFC8102E),
  ),
];

void main() {
  testWidgets('경기가 없는 날에는 다음 경기일로 가는 버튼을 보여주고, 누르면 그날 경기가 나온다', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final gameDay = today.add(const Duration(days: 23));
    final tipOff = gameDay.add(const Duration(hours: 8, minutes: 30));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teamRepositoryProvider.overrideWithValue(
            const FakeTeamRepository(teams),
          ),
          gameRepositoryProvider.overrideWithValue(
            FakeGameRepository([
              Game(
                id: 'g1',
                date: gameDay,
                homeTeamId: '8',
                awayTeamId: '2',
                homeScore: 0,
                awayScore: 0,
                status: GameStatus.scheduled,
                startTime: tipOff,
              ),
            ]),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const GamesTab()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('이 날짜엔 경기가 없어요'), findsOneWidget);
    final next = find.textContaining(
      '다음 경기 · ${gameDay.month}월 ${gameDay.day}일',
    );
    expect(next, findsOneWidget);
    // 오늘 이전 경기는 없으니 지난 경기 버튼도 없다.
    expect(find.textContaining('지난 경기'), findsNothing);

    await tester.tap(next);
    await tester.pumpAndSettle();

    expect(find.text('디트로이트 피스톤스'), findsOneWidget);
    expect(find.text('보스턴 셀틱스'), findsOneWidget);
    // 예정 경기는 팁오프 시각을 함께 보여준다.
    expect(find.text('경기 예정 · 오전 8:30'), findsOneWidget);
  });
}
