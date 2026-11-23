'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { pendingNights, nbaDay } = require('../instagram-kick');

const base = { kblDay: '2026-12-03', nbaDay: '2026-12-02', kblGames: [], nbaEvents: [], posted: {} };
const espn = (state) => ({ status: { type: { state } } });

test('경기가 다 끝났고 안 올린 리그만 깨운다', () => {
  assert.deepStrictEqual(
    pendingNights({ ...base, kblGames: [{ status: 'final' }, { status: 'final' }], nbaEvents: [espn('post'), espn('in')] }),
    ['kbl-2026-12-03'],
  );
  assert.deepStrictEqual(pendingNights({ ...base, nbaEvents: [espn('post')] }), ['nba-2026-12-02']);
});

test('경기가 없거나 이미 올렸으면 깨우지 않는다', () => {
  assert.deepStrictEqual(pendingNights(base), []);
  assert.deepStrictEqual(
    pendingNights({ ...base, kblGames: [{ status: 'final' }], posted: { 'kbl-2026-12-03': '2026-12-03T13:00:00Z' } }),
    [],
  );
});

test('미국 경기일은 동부 오전 6시(UTC 11시)에 넘어간다', () => {
  assert.strictEqual(nbaDay(Date.parse('2026-11-23T10:59:00Z')), '2026-11-22');
  assert.strictEqual(nbaDay(Date.parse('2026-11-23T11:00:00Z')), '2026-11-23');
});
