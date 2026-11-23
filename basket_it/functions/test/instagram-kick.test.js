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

test('경기 일정: 첫 경기 12시간 전에, 새벽이면 아침 9시에, 한 번만', () => {
  const { dueSchedule } = require('../instagram-kick');
  const at = (kst) => Date.parse(`${kst}+09:00`);
  const nba = [{ startTime: '2026-11-24T00:00:00Z' }, { startTime: '2026-11-24T03:00:00Z' }]; // 한국 11/24 9시·12시
  assert.strictEqual(dueSchedule('nba', nba, {}, at('2026-11-23T20:59:00')), null); // 12시간 전(21시) 전
  assert.strictEqual(dueSchedule('nba', nba, {}, at('2026-11-23T21:00:00')), '2026-11-24');
  assert.strictEqual(dueSchedule('nba', nba, { 'nba-schedule-2026-11-24': 'x' }, at('2026-11-23T22:00:00')), null);
  assert.strictEqual(dueSchedule('nba', nba, {}, at('2026-11-24T09:30:00')), null); // 첫 경기가 이미 시작
  const kbl = [{ startTime: '2026-12-05T05:00:00Z' }]; // 한국 12/5 14시 → 새벽 2시 대신 아침 9시
  assert.strictEqual(dueSchedule('kbl', kbl, {}, at('2026-12-05T02:00:00')), null);
  assert.strictEqual(dueSchedule('kbl', kbl, {}, at('2026-12-05T09:00:00')), '2026-12-05');
});
