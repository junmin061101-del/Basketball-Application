'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  TEAMS,
  isCompleteBoxScore,
  isFinalBoxScore,
  kstDate,
  pointsAgainstByTeam,
  seasonHighlights,
  seasonLabel,
  startedSeasons,
  toBoxLine,
  toGame,
  toPlayer,
  toSeasonAverages,
  toTeam,
  toTeamStats,
} = require('../../tools/fetch-kbl');

test('KBL 팀 코드는 앱이 써 온 팀 id로 옮긴다 (팔로우·뉴스 매칭 유지)', () => {
  assert.deepEqual(
    Object.values(TEAMS).map((t) => t.id).sort(),
    ['db', 'kcc', 'kgc', 'kogas', 'kt', 'lg', 'mobis', 'samsung', 'sk', 'sono'],
  );
  assert.equal(toTeam('55').logo, 'https://www.kbl.or.kr/assets/img/club/sk/emblem-sk01.png');
  assert.equal(toTeam('06').id, 'kt');
  // 소노는 PNG 엠블럼이 없어 홈페이지의 SVG 아이콘을 쓴다
  assert.match(toTeam('66').logo, /ic-sono\.svg$/);
});

test('시즌 이름과 기준 시즌: 아직 시작 안 한 시즌은 건너뛴다', () => {
  assert.equal(seasonLabel('2025-2026'), '2025-26');
  const seasons = [
    { glkey: 'S49G01', seasonName: '2026-2027', seasonCategory: 'R', gamedateStart: '20261003' },
    { glkey: 'S47G01', seasonName: '2025-2026', seasonCategory: 'R', gamedateStart: '20251003' },
    { glkey: 'S45G01', seasonName: '2024-2025', seasonCategory: 'R', gamedateStart: '20241019' },
  ];
  assert.deepEqual(startedSeasons(seasons, '20260910').map((s) => s.glkey), ['S47G01', 'S45G01']);
  assert.equal(startedSeasons(seasons, '20261003')[0].glkey, 'S49G01');
});

test('한국 날짜는 UTC 자정 직후에도 하루 앞선다', () => {
  assert.equal(kstDate(0, new Date('2026-09-10T16:00:00Z')), '20260911');
  assert.equal(kstDate(1, new Date('2026-09-10T01:00:00Z')), '20260911');
});

test('선수: 포지션·등번호·사진·팀을 옮긴다', () => {
  const p = toPlayer({
    pcode: '291001', pname: '강상재', tcode: '16', backNum: '26', pos: 'FD',
    img: 'https://kbl.or.kr/files/kbl/players-photo/291001.png',
  });
  assert.deepEqual(p, {
    id: '291001',
    name: '강상재',
    teamId: 'db',
    position: 'sf',
    positionLabel: '포워드',
    backNumber: 26,
    headshot: 'https://kbl.or.kr/files/kbl/players-photo/291001.png',
  });
});

test('경기: 한국 시간·상태·KBL 구단끼리가 아닌 경기 제외', () => {
  const game = toGame({
    gmkey: 'S47G01N1', glkey: 'S47G01', gameDate: '20251003', gameStart: '1400',
    tcodeH: '50', tcodeA: '55', scoreH: 81, scoreA: 89, isStarted: 1, isEnded: 1,
  });
  assert.equal(game.startTime, '2025-10-03T14:00:00+09:00');
  assert.equal(Date.parse(game.startTime), Date.parse('2025-10-03T05:00:00Z'));
  assert.deepEqual([game.homeTeamId, game.awayTeamId, game.homeScore, game.awayScore, game.status], ['lg', 'sk', 81, 89, 'finished']);

  const live = toGame({ gmkey: 'x', gameDate: '20251004', gameStart: '1600', tcodeH: '16', tcodeA: '35', isStarted: 1, isEnded: 0, playingQuarter: '3' });
  assert.deepEqual([live.status, live.liveClock], ['live', '3쿼터']);

  // 국제 대회 상대처럼 모르는 팀 코드
  assert.equal(toGame({ gmkey: 'y', gameDate: '20251005', tcodeH: '50', tcodeA: '99' }), null);
});

test('박스스코어: 전체 야투는 fgt, 뛰지 않은 선수는 뺀다', () => {
  const player = { pcode: '290284', pname: '허일영', tcode: '50', img: 'img' };
  const line = toBoxLine({
    player,
    records: { playMin: 22, playSec: 34, score: 6, fg: 2, fgA: 4, fgt: 2, fgtA: 8, threep: 0, threepA: 4, ft: 2, ftA: 2, offr: 1, defr: 4, ast: 0, to: 0, stl: 1, bs: 1, foul: 4, marginCn: -8 },
  });
  assert.deepEqual(
    [line.minutes, line.points, line.fgm, line.fga, line.tpa, line.oreb + line.dreb, line.plusMinus, line.teamId],
    [23, 6, 2, 8, 4, 5, -8, 'lg'],
  );
  assert.equal(toBoxLine({ player, records: { playMin: 0, playSec: 0 } }), null);
});

test('시즌 평균: 누적을 출전 경기 수로 나눈다', () => {
  const avg = toSeasonAverages({
    player: { pcode: '291248', tcode: '55' },
    gameCount: 50,
    records: { playMin: 1500, playSec: 0, score: 1158, fgt: 450, fgtA: 800, threep: 10, threepA: 30, ft: 248, ftA: 350, offr: 150, defr: 450, rb: 600, ast: 200, to: 100, stl: 60, bs: 40, foul: 120 },
  });
  assert.equal(avg.teamId, 'sk');
  assert.equal(avg.gamesPlayed, 50);
  assert.equal(avg.minutes, 30);
  assert.equal(avg.points, 23.16);
  assert.equal(avg.reb, 12);
});

test('팀 평균: 순위 데이터의 fg(2점)에 3점을 더해 전체 야투로', () => {
  const s = toTeamStats(
    { teamCode: '50', gameCount: 54, score: 4164, fg: 1105, fgA: 2224, threep: 481, threepA: 1384, ft: 511, ftA: 789, OR: 599, DR: 1431, AS: 1024, ST: 345, BS: 115, TO: 593, foulTot: 1000 },
    72.5,
  );
  assert.equal(s.teamId, 'lg');
  assert.equal(s.fgm, (1105 + 481) / 54);
  assert.equal(s.rebounds, (599 + 1431) / 54);
  assert.equal(s.pointsAgainst, 72.5);
  // 2점×2 + 3점×3 + 자유투 = 득점
  assert.equal(((1105 * 2 + 481 * 3 + 511) / 54).toFixed(4), s.pointsFor.toFixed(4));
});

test('실점은 끝난 경기 결과로 계산한다', () => {
  const againts = pointsAgainstByTeam([
    { homeTeamId: 'lg', awayTeamId: 'sk', homeScore: 81, awayScore: 89, status: 'finished' },
    { homeTeamId: 'sk', awayTeamId: 'lg', homeScore: 70, awayScore: 75, status: 'finished' },
    { homeTeamId: 'sk', awayTeamId: 'lg', homeScore: 0, awayScore: 0, status: 'scheduled' },
  ]);
  assert.equal(againts.get('lg'), (89 + 70) / 2);
  assert.equal(againts.get('sk'), (81 + 75) / 2);
});

test('더블더블·트리플더블·최다 득점을 박스스코어로 센다', () => {
  const line = (points, oreb, dreb, ast, stl = 0, blk = 0) => ({ playerId: 'p', points, oreb, dreb, ast, stl, blk });
  const h = seasonHighlights([
    { lines: [line(20, 3, 8, 2)] }, // 더블더블
    { lines: [line(15, 2, 9, 11)] }, // 트리플더블
    { lines: [line(33, 1, 2, 3)] },
  ]).get('p');
  assert.deepEqual(h, { dd2: 2, td3: 1, gameHigh: 33 });
});

// 경기 중에 받은 반쪽 기록이 끝난 경기의 기록으로 굳는 것을 막는 규칙.
// (2026-09-26 SK-DB 경기가 선발 5명씩 10줄로 몇 날 동안 남아 있었다.)
const boxOf = (count) => ({
  lines: Array.from({ length: count }, (_, i) => ({ teamId: i * 2 < count ? 'sk' : 'db' })),
});

test('끝난 경기라도 양 팀 기록이 다 와야 최종으로 적어 둔다', () => {
  const now = new Date('2026-09-29T00:00:00Z');
  const justEnded = { status: 'finished', startTime: '2026-09-28T22:00:00+09:00' };
  const longAgo = { status: 'finished', startTime: '2026-09-26T19:00:00+09:00' };

  assert.equal(isFinalBoxScore(boxOf(24), justEnded, now), true);
  // 끝난 직후에는 기록 API가 늦게 채워질 수 있어 반쪽이면 최종으로 보지 않는다.
  assert.equal(isFinalBoxScore(boxOf(10), justEnded, now), false);
  // 반나절이 지났으면 더 채워질 것이 없다(선수가 적게 뛴 경기도 있다).
  assert.equal(isFinalBoxScore(boxOf(10), longAgo, now), true);
  // 진행 중인 경기는 언제나 최종이 아니다.
  assert.equal(isFinalBoxScore(boxOf(24), { status: 'live', startTime: '2026-09-28T23:00:00+09:00' }, now), false);
});

test('최종 표시가 없거나 반쪽인 기록은 다시 쓰지 않는다', () => {
  assert.equal(isCompleteBoxScore({ final: true, lines: boxOf(2).lines }), true);
  assert.equal(isCompleteBoxScore({ final: false, lines: boxOf(24).lines }), false);
  // 표시가 없던 예전 파일은 양 팀 기록이 다 들어 있을 때만 그대로 쓴다.
  assert.equal(isCompleteBoxScore(boxOf(24)), true);
  assert.equal(isCompleteBoxScore(boxOf(10)), false);
  assert.equal(isCompleteBoxScore({ final: true, lines: [] }), false);
  assert.equal(isCompleteBoxScore(null), false);
});
