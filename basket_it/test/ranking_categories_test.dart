import 'package:basket_it/data/models/player_season_stats.dart';
import 'package:basket_it/features/explore/ranking_categories.dart';
import 'package:flutter_test/flutter_test.dart';

PlayerSeasonStats stat(
  String id, {
  int games = 70,
  double points = 0,
  double blocks = 0,
  double fgm = 0,
  double fga = 0,
  double oreb = 0,
  double dreb = 0,
  bool split = true,
  int? doubleDoubles,
}) => PlayerSeasonStats(
  playerId: id,
  season: '2025-26',
  teamId: '1',
  gamesPlayed: games,
  minutes: 30,
  points: points,
  fgm: fgm,
  fga: fga,
  tpm: 0,
  tpa: 0,
  ftm: 0,
  fta: 0,
  oreb: oreb,
  dreb: dreb,
  ast: 0,
  tov: 0,
  stl: 0,
  blk: blocks,
  pf: 0,
  plusMinus: 0,
  doubleDoubles: doubleDoubles,
  hasReboundSplit: split,
);

RankingCategory category(String label) =>
    rankingCategories.firstWhere((c) => c.label == label);

void main() {
  test('네이버 스포츠와 같은 20개 부문', () {
    expect(rankingCategories.map((c) => c.label), [
      '득점',
      '리바운드',
      '어시스트',
      '스틸',
      '블록',
      '3점슛 성공',
      '야투율',
      '3점슛 성공률',
      '자유투 성공률',
      '야투 성공',
      '자유투 성공',
      '공격 리바운드',
      '수비 리바운드',
      '더블더블',
      '트리플더블',
      '한 경기 최다 득점',
      '출전 시간',
      '출전 경기',
      '턴오버',
      '파울',
    ]);
  });

  test('경기당 기록은 가장 많이 뛴 선수의 70% 미만 출전자를 뺀다', () {
    final rows = rankPlayers([
      stat('full', games: 80, points: 25),
      stat('edge', games: 56, points: 20),
      // 두 경기 평균 40점은 1위가 되면 안 된다
      stat('cameo', games: 2, points: 40),
    ], category('득점'));
    expect(rows.map((r) => r.stats.playerId), ['full', 'edge']);
  });

  test('성공률은 한두 번 던져 다 넣은 선수를 빼고 누적 성공 개수로 거른다', () {
    final rows = rankPlayers([
      // 82경기 × 4.0개 = 328개 ≥ 300개
      stat('volume', games: 82, fgm: 4.0, fga: 8.0),
      // 10경기 × 1개 = 10개, 100%
      stat('perfect', games: 10, fgm: 1.0, fga: 1.0),
    ], category('야투율'));
    expect(rows.map((r) => r.stats.playerId), ['volume']);
    expect(rows.single.value, closeTo(50, 0.001));
  });

  test('시즌 중에는 성공 개수 기준을 치른 경기 수에 비례해 낮춘다', () {
    final context = RankingContext.of([stat('a', games: 41)]);
    // 300 × 41/82 = 150
    expect(context.minMade(RankingQualifier.fieldGoal), 150);
    expect(context.minGames, 29);
  });

  test('화면에 보이는 값이 같으면 공동 순위', () {
    final rows = rankPlayers([
      stat('a', blocks: 1.94),
      stat('b', blocks: 1.86),
      stat('c', blocks: 1.7),
    ], category('블록'));
    expect(rows.map((r) => r.rank), [1, 1, 3]);
  });

  test('누적 기록은 출전 수 제한 없이 줄 세운다', () {
    final rows = rankPlayers([
      stat('a', games: 80, doubleDoubles: 50),
      stat('b', games: 10, doubleDoubles: 8),
    ], category('더블더블'));
    expect(rows.map((r) => r.stats.playerId), ['a', 'b']);
  });

  test('리그가 주지 않는 기록은 부문째 숨긴다', () {
    final kbl = [stat('a', points: 20), stat('b', points: 15)];
    expect(isCategoryAvailable(kbl, category('더블더블')), isFalse);
    expect(isCategoryAvailable(kbl, category('득점')), isTrue);
  });

  test('공격/수비로 안 나뉜 선수는 리바운드 부문 순위에 들지 않는다', () {
    final rows = rankPlayers([
      stat('split', oreb: 3, dreb: 9),
      // 총합 12개가 수비 쪽에 들어 있다
      stat('totalOnly', oreb: 0, dreb: 12, split: false),
    ], category('수비 리바운드'));
    expect(rows.map((r) => r.stats.playerId), ['split']);
    // 리바운드 총합 순위에는 둘 다 든다
    expect(
      rankPlayers([
        stat('split', oreb: 3, dreb: 9),
        stat('totalOnly', oreb: 0, dreb: 12, split: false),
      ], category('리바운드')).length,
      2,
    );
  });
}
