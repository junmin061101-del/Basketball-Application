'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { calendarDay, conferenceKey, dateRanges, sortStandings } = require('../../tools/fetch-nba');

test('컨퍼런스 이름을 east / west로 줄인다', () => {
  assert.equal(conferenceKey('Eastern Conference'), 'east');
  assert.equal(conferenceKey('Western Conference'), 'west');
  assert.equal(conferenceKey(undefined), '');
});

test('순위: 동부 먼저, 컨퍼런스 안에서는 시드순(승률이 같아도 시드를 따른다)', () => {
  const row = (teamId, conference, seed, wins, losses) => ({ teamId, conference, seed, wins, losses });
  const sorted = sortStandings([
    row('LAL', 'west', 4, 50, 32),
    row('ATL', 'east', 6, 46, 36),
    row('OKC', 'west', 1, 64, 18),
    row('DET', 'east', 1, 60, 22),
    // 승률이 ATL과 같지만 타이브레이커로 5번 시드
    row('ORL', 'east', 5, 46, 36),
    row('SA', 'west', 2, 62, 20),
  ]);
  assert.deepEqual(sorted.map((r) => r.teamId), ['DET', 'ORL', 'ATL', 'OKC', 'SA', 'LAL']);
});

test('시드가 없으면 컨퍼런스 안에서 승률순', () => {
  const sorted = sortStandings([
    { teamId: 'a', conference: 'east', seed: null, wins: 10, losses: 20 },
    { teamId: 'b', conference: 'east', seed: null, wins: 20, losses: 10 },
  ]);
  assert.deepEqual(sorted.map((r) => r.teamId), ['b', 'a']);
});

test('ESPN 달력 날짜는 날짜 부분만 쓴다', () => {
  assert.equal(calendarDay('2026-10-20T07:00Z'), '20261020');
  assert.equal(calendarDay('2026-11-02T08:00Z'), '20261102');
  assert.equal(calendarDay(null), null);
});

test('경기일을 5일 구간으로 묶고 긴 공백은 건너뛴다', () => {
  const days = ['20261020', '20261021', '20261024', '20261025', '20261026', '20261226', '20261020'];
  assert.deepEqual(dateRanges(days), ['20261020-20261024', '20261025-20261029', '20261226-20261230']);
  // 월말을 넘어가는 구간
  assert.deepEqual(dateRanges(['20261030'], 5), ['20261030-20261103']);
  assert.deepEqual(dateRanges([]), []);
});
