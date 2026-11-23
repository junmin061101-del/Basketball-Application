'use strict';
// node --test tools/instagram/post.test.js
const test = require('node:test');
const assert = require('node:assert');
const { dueDate } = require('./post');

const data = (games, today = '2026-11-23') => ({ games, dayOf: (g) => g.date, today });
const g = (date, status) => ({ date, status });

test('그날 마지막 경기가 끝나면 그 날짜를 올린다', () => {
  assert.strictEqual(dueDate('nba', data([g('2026-11-22', 'finished'), g('2026-11-22', 'finished'), g('2026-11-23', 'scheduled')]), {}), '2026-11-22');
});

test('아직 하는 경기가 있으면 기다린다', () => {
  assert.strictEqual(dueDate('nba', data([g('2026-11-22', 'finished'), g('2026-11-22', 'live')]), {}), null);
});

test('이미 올린 날은 다시 올리지 않는다', () => {
  assert.strictEqual(dueDate('nba', data([g('2026-11-22', 'finished')]), { 'nba-2026-11-22': '2026-11-23T07:00:00Z' }), null);
});

test('그저께보다 오래된 경기일은 올리지 않는다(쉬는 기간)', () => {
  assert.strictEqual(dueDate('kbl', data([g('2026-11-19', 'finished'), g('2026-12-03', 'scheduled')]), {}), null);
});

test('다음 날 경기가 시작되면 지난 날은 넘긴다', () => {
  assert.strictEqual(dueDate('nba', data([g('2026-11-22', 'finished'), g('2026-11-23', 'live')]), {}), null);
});
