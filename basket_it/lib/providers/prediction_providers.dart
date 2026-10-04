import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/game.dart';
import '../data/models/prediction.dart';
import '../data/repositories/prediction_repository.dart';
import 'auth_providers.dart';
import 'game_providers.dart';

final predictionRepositoryProvider = Provider<PredictionRepository>((ref) {
  return FirestorePredictionRepository();
});

/// 승부예측 대상 경기: 오늘부터 7일치. 오늘 경기는 이미 시작/종료됐어도
/// 결과 확인용으로 함께 보여준다.
final predictionGamesProvider = FutureProvider<List<Game>>((ref) async {
  final repo = ref.watch(gameRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final games = <Game>[];
  for (var d = 0; d < 7; d++) {
    games.addAll(await repo.getGamesByDate(today.add(Duration(days: d))));
  }
  return games;
});

/// 특정 경기의 실시간 투표 목록.
final gameVotesProvider = StreamProvider.family<List<PredictionVote>, String>((
  ref,
  gameId,
) {
  return ref.watch(predictionRepositoryProvider).watchVotes(gameId);
});

/// 특정 경기의 실시간 토론 댓글.
final gameCommentsProvider =
    StreamProvider.family<List<PredictionComment>, String>((ref, gameId) {
      return ref.watch(predictionRepositoryProvider).watchComments(gameId);
    });

/// 1분마다 갱신되는 "지금" — 마감 카운트다운 표시용.
final minuteTickProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

/// 현재 로그인 사용자(게스트 포함). 로그아웃 상태면 null.
final currentUserProvider = Provider((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});
