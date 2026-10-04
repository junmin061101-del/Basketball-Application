import 'package:basket_it/features/game540/game_54_0_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 선수 명단(assets/game/kbl_players_54_0.json)을 읽어 게임을 끝까지 돌린다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> openGame() async {
    Game540Controller.seed = 11;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(game540Provider.future);
    return container;
  }

  test('룰렛이 멈춰야 선수 명단이 열리고, 다섯 라운드를 돌면 결과가 나온다', () async {
    final container = await openGame();
    final controller = container.read(game540Provider.notifier);
    Game540State now() => container.read(game540Provider).value!;

    controller.start();
    final picked = <String>[];
    for (var round = 1; round <= totalRounds; round++) {
      expect(now().round, round);
      // 도는 중에는 고를 수 없다.
      expect(now().spinning, isTrue);
      controller.select(now().pool.first);
      expect(now().candidate, isNull);

      controller.settle();
      expect(now().pool, isNotEmpty);
      // 이미 자리에 넣은 선수는 다음 라운드 명단에 없다.
      expect(now().pool.map((p) => p.id), isNot(contains(picked.lastOrNull)));

      final player = now().pool.first;
      controller.select(player);
      expect(now().candidate!.id, player.id);
      picked.add(player.id);
      controller.place(now().emptySlots.first);
    }

    final end = now();
    expect(end.phase, GamePhase.finished);
    expect(end.lineup.length, totalRounds);
    expect(end.lineup.values.map((p) => p.id).toSet(), picked.toSet());
    expect(end.result!.ppg, greaterThan(0));
    expect(end.result!.wins, inInclusiveRange(0, 54));
  });

  test('다시 돌리기는 한 게임에 한 번뿐이다', () async {
    final container = await openGame();
    final controller = container.read(game540Provider.notifier);
    Game540State now() => container.read(game540Provider).value!;

    controller.start();
    controller.settle();
    final first = now().condition;

    controller.reroll();
    expect(now().rerollUsed, isTrue);
    expect(now().spinning, isTrue, reason: '다시 돌릴 때도 룰렛이 돈다');
    expect(now().condition, isNot(first));
    controller.settle();

    final second = now().condition;
    controller.reroll();
    expect(now().condition, second);
  });

  test('결과에는 무작위 라인업과 견준 순위가 붙는다', () async {
    final container = await openGame();
    final controller = container.read(game540Provider.notifier);
    Game540State now() => container.read(game540Provider).value!;

    controller.start();
    for (var round = 1; round <= totalRounds; round++) {
      controller.settle();
      controller.select(now().pool.first);
      controller.place(now().emptySlots.first);
    }

    // 순위 기준은 게임을 여는 동안 조금씩 만들어 둔다. 늦어도 결과에 붙는다.
    for (var i = 0; i < 400 && now().result!.rankPool == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final result = now().result!;
    expect(result.rankPool, 1000);
    expect(result.rank, inInclusiveRange(1, 1000));
    expect(result.topPercent, isNotNull);
  });
}
