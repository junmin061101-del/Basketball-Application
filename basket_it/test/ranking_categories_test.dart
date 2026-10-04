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
  test('네이버 스포츠 KBL 선수 기록과 같은 부문, 같은 순서', () {
    expect(rankingCategories.map((c) => c.label), [
      '득점',
      '리바운드',
      '어시스트',
      '스틸',
      '블록슛',
      '야투 성공',
      '야투 성공률',
      '3점슛 성공',
      '3점슛 성공률',
      '자유투 성공',
      '자유투 성공률',
      '공격 리바운드',
      '수비 리바운드',
      '턴오버',
      '파울',
      '출전 시간',
      '출전 경기',
      '더블더블',
      '트리플더블',
      '한 경기 최다 득점',
    ]);
  });

  test('출전 경기 수로 거르지 않는다 — 한 경기만 뛴 선수도 줄 세운다', () {
    // 네이버 스포츠 KBL 선수 기록은 1경기 출전 선수까지 모두 보여준다.
    final rows = rankPlayers([
      stat('full', games: 54, points: 25),
      stat('cameo', games: 1, points: 40),
      stat('half', games: 27, points: 20),
    ], category('득점'));
    expect(rows.map((r) => r.stats.playerId), ['cameo', 'full', 'half']);
  });

  test('성공률도 시도 횟수로 거르지 않는다', () {
    final rows = rankPlayers([
      stat('volume', games: 54, fgm: 8.0, fga: 15.0),
      stat('perfect', games: 1, fgm: 1.0, fga: 1.0),
    ], category('야투 성공률'));
    expect(rows.map((r) => r.stats.playerId), ['perfect', 'volume']);
  });

  test('값이 정확히 같을 때만 공동 순위, 다음 순위는 건너뛴다', () {
    final rows = rankPlayers([
      stat('a', blocks: 1.9),
      stat('b', blocks: 1.9),
      stat('c', blocks: 1.86),
      stat('d', blocks: 1.7),
    ], category('블록슛'));
    expect(rows.map((r) => r.rank), [1, 1, 3, 4]);
  });

  test('한 경기도 못 뛴 선수는 빼고 줄 세운다', () {
    final rows = rankPlayers([
      stat('played', games: 3, points: 10),
      stat('none', games: 0, points: 0),
    ], category('득점'));
    expect(rows.map((r) => r.stats.playerId), ['played']);
  });

  test('누적 기록도 그대로 줄 세운다', () {
    final rows = rankPlayers([
      stat('a', games: 54, doubleDoubles: 50),
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
