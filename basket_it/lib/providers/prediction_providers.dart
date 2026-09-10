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

/// 승부예측 랭킹. 결과가 확정된(종료된) 경기의 투표만 채점한다.
/// 정렬: 맞힌 수 내림차순 → 동률이면 이름 가나다순.
final leaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) async {
  final votes = await ref.watch(predictionRepositoryProvider).getAllVotes();
  if (votes.isEmpty) return const [];

  final gameRepo = ref.watch(gameRepositoryProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // 날짜별로 경기를 한 번씩만 불러와서 gameId → 승자(홈/원정) 매핑을 만든다.
  final winners = <String, TeamSide?>{};
  final dates = votes
      .map((v) => DateTime(v.gameDate.year, v.gameDate.month, v.gameDate.day))
      .toSet();
  for (final date in dates) {
    if (!date.isBefore(today)) continue; // 오늘/미래 경기는 아직 미확정
    for (final g in await gameRepo.getGamesByDate(date)) {
      if (g.status != GameStatus.finished) continue;
      winners[g.id] = g.homeScore == g.awayScore
          ? null
          : (g.homeScore > g.awayScore ? TeamSide.home : TeamSide.away);
    }
  }

  final byUid = <String, ({String name, int correct, int settled})>{};
  for (final v in votes) {
    final current = byUid[v.uid] ?? (name: v.displayName, correct: 0, settled: 0);
    if (!winners.containsKey(v.gameId)) {
      byUid[v.uid] = (name: v.displayName, correct: current.correct, settled: current.settled);
      continue;
    }
    final winner = winners[v.gameId];
    if (winner == null) {
      // 무승부 경기는 적중/실패 어느 쪽도 아니므로 집계에서 제외한다.
      byUid[v.uid] = (
        name: v.displayName,
        correct: current.correct,
        settled: current.settled,
      );
      continue;
    }
    byUid[v.uid] = (
      name: v.displayName,
      correct: current.correct + (winner == v.pick ? 1 : 0),
      settled: current.settled + 1,
    );
  }

  final entries = byUid.entries
      .map(
        (e) => LeaderboardEntry(
          uid: e.key,
          displayName: e.value.name,
          correct: e.value.correct,
          settled: e.value.settled,
        ),
      )
      .toList();
  entries.sort((a, b) {
    final byCorrect = b.correct.compareTo(a.correct);
    if (byCorrect != 0) return byCorrect;
    return a.displayName.compareTo(b.displayName); // 동률: 가나다순
  });
  return entries;
});

/// 현재 로그인 사용자(게스트 포함). 로그아웃 상태면 null.
final currentUserProvider = Provider((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});
