'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { toGame } = require('../../tools/fetch-nba');

const raw = (status, over = {}) => ({
  id: 1, date: '2026-11-18', datetime: '2026-11-19T00:30:00Z', status,
  home_team: { abbreviation: 'LAL' }, visitor_team: { abbreviation: 'UTA' },
  home_team_score: 101, visitor_team_score: 99, ...over,
});

test('NBA 경기 상태: Final은 종료, 날짜 문자열은 예정, 나머지는 진행 중', () => {
  assert.strictEqual(toGame(raw('Final')).status, 'finished');
  assert.strictEqual(toGame(raw('4th Qtr')).status, 'live');
  assert.strictEqual(toGame(raw('2026-11-20T00:00:00Z', { datetime: null })).status, 'scheduled');
  assert.strictEqual(toGame(raw('Final', { home_team: { abbreviation: 'XXX' } })), null); // 올스타전 등
});

test('쿼터별 점수: 있으면 담고(연장 포함), 없으면 null', () => {
  const q = toGame(raw('Final', {
    home_q1: 25, home_q2: 30, home_q3: 20, home_q4: 21, home_ot1: 5,
    visitor_q1: 28, visitor_q2: 22, visitor_q3: 24, visitor_q4: 22, visitor_ot1: 3,
  })).quarters;
  assert.deepStrictEqual(q, { home: [25, 30, 20, 21, 5], away: [28, 22, 24, 22, 3] });
  assert.strictEqual(toGame(raw('Final')).quarters, null);
});
