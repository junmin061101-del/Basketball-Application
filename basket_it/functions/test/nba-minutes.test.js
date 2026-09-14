'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const { reconstructSeconds } = require('../../tools/fetch-nba');

/** 팀 하나(5명 + 후보 1명)만 뛰는 짧은 가상 경기. */
function summary({ espnMinutes, subs, periods = 4 }) {
  const athletes = ['s1', 's2', 's3', 's4', 's5', 'b1'].map((id) => ({
    athlete: { id },
    starter: id.startsWith('s'),
    stats: [String(espnMinutes[id] ?? 0)],
  }));
  const plays = [];
  for (let p = 1; p <= periods; p += 1) {
    plays.push({ period: { number: p }, type: { text: 'Jump Shot' }, clock: { displayValue: '11:50' }, participants: [{ athlete: { id: 's1' } }] });
    for (const sub of subs.filter((x) => x.period === p)) {
      plays.push({
        period: { number: p },
        type: { text: 'Substitution' },
        clock: { displayValue: sub.clock },
        participants: [{ athlete: { id: sub.in } }, { athlete: { id: sub.out } }],
      });
    }
  }
  return { plays, boxscore: { players: [{ team: { id: 'A' }, statistics: [{ athletes }] }] } };
}

test('교체 기록으로 코트에 있던 구간을 이어 초 단위 출전 시간을 만든다', () => {
  // 4쿼터 동안 s5가 1쿼터 7:26에 b1과 교체, 2쿼터 6:00에 다시 들어온다
  const s = summary({
    espnMinutes: { s1: 48, s2: 48, s3: 48, s4: 48, s5: 38, b1: 10 },
    subs: [
      { period: 1, clock: '7:26', in: 'b1', out: 's5' },
      { period: 2, clock: '6:00', in: 's5', out: 'b1' },
    ],
  });
  const seconds = reconstructSeconds(s);
  // b1: 1쿼터 7:26(446초) + 2쿼터 6:00까지 360초 = 806초(13:26)... ESPN이 10분이라면 맞지 않는다
  assert.equal(seconds.has('b1'), false);
  assert.equal(seconds.has('s5'), false);

  // ESPN 분 기록과 맞으면 초를 준다: b1 = 446 + (720 - 360) = 806초 → 13분, s5 = 2880 - 806 = 2074초 → 35분
  const ok = reconstructSeconds(
    summary({
      espnMinutes: { s1: 48, s2: 48, s3: 48, s4: 48, s5: 35, b1: 13 },
      subs: [
        { period: 1, clock: '7:26', in: 'b1', out: 's5' },
        { period: 2, clock: '6:00', in: 's5', out: 'b1' },
      ],
    }),
  );
  assert.equal(ok.get('b1'), 806);
  assert.equal(ok.get('s5'), 2074);
  assert.equal(ok.get('s1'), 2880);
});

test('팀 합이 5명 × 경기 시간이 아니면(교체 기록 누락) 그 팀은 초를 주지 않는다', () => {
  // s5를 내보내는 기록 없이 b1만 들어왔다고 적힌 경우 → 코트에 6명이 된다
  const s = summary({
    espnMinutes: { s1: 48, s2: 48, s3: 48, s4: 48, s5: 48, b1: 5 },
    subs: [{ period: 4, clock: '5:00', in: 'b1', out: 'nobody' }],
  });
  assert.equal(reconstructSeconds(s).size, 0);
});

test('문자중계가 없으면(연기된 경기 등) 빈 결과', () => {
  assert.equal(reconstructSeconds({ plays: [], boxscore: { players: [] } }).size, 0);
  assert.equal(reconstructSeconds(null).size, 0);
});
