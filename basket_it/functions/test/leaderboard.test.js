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

test('마감 뒤 투표 지우기·바꾸기는 되돌리고, 마감 전 변경과 늦은 투표는 그대로 둔다', () => {
  const { lockedVote } = require('../leaderboard');
  const game = { id: 'g1', startTime: '2026-12-03T10:00:00Z' }; // 마감 09:00Z
  const at = (iso) => ({ toMillis: () => Date.parse(iso) });
  const early = { uid: 'bob', gameId: 'g1', pick: 'home', createdAt: at('2026-12-03T08:00:00Z') };
  const after = Date.parse('2026-12-03T12:30:00Z');
  assert.strictEqual(lockedVote(early, undefined, game, after), early); // 끝나고 지움
  assert.strictEqual(lockedVote(early, { ...early, pick: 'away', createdAt: at('2026-12-03T12:30:00Z') }, game, after), early);
  assert.strictEqual(lockedVote(early, undefined, game, Date.parse('2026-12-03T08:30:00Z')), null); // 마감 전 취소
  const late = { ...early, createdAt: at('2026-12-03T09:30:00Z') };
  assert.strictEqual(lockedVote(late, undefined, game, after), null); // 채점 안 되는 투표
  assert.strictEqual(lockedVote(early, { ...early }, game, after), null); // 바뀐 것 없음
  assert.strictEqual(lockedVote(early, undefined, undefined, after), null); // 모르는 경기
});

test('랭킹: KBL·NBA를 따로 채점해 leaderboard/kbl·nba에 적는다', async () => {
  const { updateLeaderboard } = require('../leaderboard');
  const store = {};
  const ts = (iso) => ({ toMillis: () => Date.parse(iso) });
  const votes = [
    { uid: 'a', displayName: '에이', gameId: 'k1', pick: 'home', createdAt: ts('2026-12-03T08:00:00Z') },
    { uid: 'a', displayName: '에이', gameId: 'nba-9', pick: 'away', createdAt: ts('2026-11-23T20:00:00Z') },
    { uid: 'b', displayName: '비비', gameId: 'nba-9', pick: 'home', createdAt: ts('2026-11-23T20:00:00Z') },
  ];
  const db = {
    collection: (name) => ({
      get: async () => ({ docs: name === 'predictionVotes' ? votes.map((v) => ({ data: () => v })) : [] }),
      doc: (id) => ({
        get: async () => ({ exists: false, get: () => undefined }),
        set: async (v) => { store[`${name}/${id}`] = v; },
      }),
    }),
    batch: () => ({ set: (ref, v) => ref.set(v), commit: async () => {} }),
  };
  const data = {
    kbl: [{ id: 'k1', status: 'finished', startTime: '2026-12-03T10:00:00Z', homeScore: 80, awayScore: 70 }],
    nba: [{ id: '9', status: 'finished', startTime: '2026-11-24T00:00:00Z', homeScore: 100, awayScore: 110 }],
  };
  const fetchImpl = async (url) => ({ ok: true, json: async () => ({ games: data[url.includes('/nba/') ? 'nba' : 'kbl'] }) });
  await updateLeaderboard({ db, fetchImpl });
  const pick = (doc) => store[doc].entries.map((e) => `${e.uid}:${e.correct}/${e.settled}`);
  assert.deepStrictEqual(pick('leaderboard/kbl'), ['a:1/1']);
  assert.deepStrictEqual(pick('leaderboard/nba'), ['a:1/1', 'b:0/1']);
});
