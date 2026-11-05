'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { scoreLeaderboard, tallyVotes, tallyChange } = require('../leaderboard');

const start = '2026-11-05T19:00:00+09:00';
const before = Date.parse(start) - 2 * 60 * 60 * 1000; // 마감 전
const after = Date.parse(start) + 3 * 60 * 60 * 1000; // 경기가 끝난 뒤
const games = [
  { id: 'g1', startTime: start, status: 'finished', homeScore: 80, awayScore: 70 },
  { id: 'g2', startTime: start, status: 'scheduled', homeScore: 0, awayScore: 0 },
  { id: 'g3', startTime: start, status: 'finished', homeScore: 70, awayScore: 70 },
];
const vote = (uid, gameId, pick, createdAtMs, displayName = uid) => ({ uid, displayName, gameId, pick, createdAtMs });

test('마감 전 투표만 채점하고, 맞힌 수 → 이름 순으로 세운다', () => {
  const board = scoreLeaderboard(
    [
      vote('a', 'g1', 'home', before), // 맞힘
      vote('b', 'g1', 'away', before), // 틀림
      vote('c', 'g1', 'home', after), // 결과를 보고 쓴 투표 → 채점 안 함
      vote('d', 'g1', 'home', NaN), // 시각 없음 → 채점 안 함
      vote('b', 'g2', 'home', before), // 아직 안 끝난 경기
      vote('a', 'g3', 'home', before), // 무승부
    ],
    games,
  );
  assert.deepStrictEqual(
    board.map((p) => [p.uid, p.correct, p.settled]),
    [['a', 1, 1], ['b', 0, 1], ['c', 0, 0], ['d', 0, 0]],
  );
});

test('투표 수: 경기별로 세고, 고르기·바꾸기·취소를 증감으로 바꾼다', () => {
  assert.deepStrictEqual(
    tallyVotes([vote('a', 'g1', 'home'), vote('b', 'g1', 'away'), vote('c', 'g1', 'home'), vote('d', 'g2', 'away')]),
    { g1: { home: 2, away: 1 }, g2: { home: 0, away: 1 } },
  );
  const v = (pick) => ({ gameId: 'g1', pick });
  assert.deepStrictEqual(tallyChange(undefined, v('home')), [['g1', 'home', 1]]);
  assert.deepStrictEqual(tallyChange(v('home'), v('away')), [['g1', 'home', -1], ['g1', 'away', 1]]);
  assert.deepStrictEqual(tallyChange(v('home'), v('home')), []); // 이름만 바뀐 경우
  assert.deepStrictEqual(tallyChange(v('away'), undefined), [['g1', 'away', -1]]);
});
