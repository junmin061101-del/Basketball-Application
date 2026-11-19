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
