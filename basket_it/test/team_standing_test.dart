import 'package:basket_it/data/models/team_standing.dart';
import 'package:flutter_test/flutter_test.dart';

TeamStanding row(
  String teamId, {
  String conference = '',
  int? seed,
  int wins = 0,
  int losses = 0,
}) => TeamStanding(
  teamId: teamId,
  wins: wins,
  losses: losses,
  gamesBehind: 0,
  conference: conference,
  seed: seed,
);

void main() {
  test('NBA는 동부·서부 두 표로 나누고 각각 시드순으로 1위부터 매긴다', () {
    final groups = groupStandings([
      row('LAL', conference: 'west', seed: 4),
      row('ATL', conference: 'east', seed: 6),
      row('OKC', conference: 'west', seed: 1),
      row('DET', conference: 'east', seed: 1),
      row('BOS', conference: 'east', seed: 2),
    ]);
    expect(groups.map((g) => g.title), ['동부 컨퍼런스', '서부 컨퍼런스']);
    expect(groups[0].rows.map((s) => s.teamId), ['DET', 'BOS', 'ATL']);
    expect(groups[1].rows.map((s) => s.teamId), ['OKC', 'LAL']);
  });

  test('예전 수집 결과(긴 컨퍼런스 이름, 시드 없음)도 나누고 원본 순서를 지킨다', () {
    final groups = groupStandings([
      row('OKC', conference: 'Western Conference', wins: 64),
      row('DET', conference: 'Eastern Conference', wins: 60),
      row('SA', conference: 'Western Conference', wins: 62),
    ]);
    expect(groups.map((g) => g.title), ['동부 컨퍼런스', '서부 컨퍼런스']);
    expect(groups[1].rows.map((s) => s.teamId), ['OKC', 'SA']);
  });

  test('KBL처럼 컨퍼런스가 없으면 제목 없는 표 하나, 원본(공식 순위) 순서', () {
    final groups = groupStandings([row('lg'), row('kgc'), row('db')]);
    expect(groups, hasLength(1));
    expect(groups.single.title, isNull);
    expect(groups.single.rows.map((s) => s.teamId), ['lg', 'kgc', 'db']);
  });

  test('순위 표기: NBA는 컨퍼런스 순위, KBL은 리그 순위', () {
    final nba = [
      row('DET', conference: 'east', seed: 1),
      row('OKC', conference: 'west', seed: 1),
      row('BOS', conference: 'east', seed: 2),
    ];
    expect(rankLabelOf(nba, 'BOS'), '동부 2위');
    expect(rankLabelOf(nba, 'OKC'), '서부 1위');
    expect(rankLabelOf([row('lg'), row('kgc')], 'kgc'), '리그 2위');
    expect(rankLabelOf(nba, 'nope'), isNull);
  });
}
