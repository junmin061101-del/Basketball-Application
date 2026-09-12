'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  calendarDay,
  conferenceKey,
  dateRanges,
  daysBetween,
  fetchHistoryGames,
  inWindow,
  seasonLabel,
  seasonStartYear,
  seasonWindow,
  sortStandings,
} = require('../../tools/fetch-nba');

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

test('시즌 시작 연도·표기·기간: 8월 이후는 그 해 개막 시즌', () => {
  assert.equal(seasonStartYear(new Date('2026-09-12T00:00:00Z')), 2026);
  assert.equal(seasonStartYear(new Date('2027-04-12T00:00:00Z')), 2026);
  assert.equal(seasonLabel(2023), '2023-24');
  assert.equal(seasonLabel(1999), '1999-00');
  assert.deepEqual(seasonWindow(2023), ['20230915', '20240701']);
  assert.deepEqual(daysBetween('20231230', '20240102'), ['20231230', '20231231', '20240101', '20240102']);
  assert.equal(inWindow('2024-01-05T01:00Z', '20230915', '20240701'), true);
  assert.equal(inWindow('2023-09-14T01:00Z', '20230915', '20240701'), false);
});

test('지난 시즌 일정: 다 모은 시즌은 다시 받지 않고, 실패하면 지난 결과를 지킨다', async () => {
  const teamIds = new Set(['13', '2']);
  const game = (id, date) => ({
    id,
    date,
    competitions: [
      {
        status: { type: { completed: true, state: 'post' } },
        competitors: [
          { homeAway: 'home', score: '101', team: { id: '13' } },
          { homeAway: 'away', score: '99', team: { id: '2' } },
        ],
      },
    ],
  });

  const calls = [];
  const originalFetch = global.fetch;
  const respond = (body, ok = true) => ({ ok, status: ok ? 200 : 500, json: async () => body });
  try {
    // 1) 세 시즌 모두 완료로 기록돼 있으면 요청하지 않는다
    global.fetch = async (url) => {
      calls.push(url);
      return respond({ events: [] });
    };
    const previous = {
      history_seasons: ['2025-26', '2024-25', '2023-24'],
      games: [
        { id: 'a', startTime: '2026-01-05T01:00Z', status: 'finished' },
        { id: 'b', startTime: '2025-01-05T01:00Z', status: 'finished' },
        { id: 'c', startTime: '2024-01-05T01:00Z', status: 'finished' },
        { id: 'skip', startTime: '2019-01-05T01:00Z', status: 'finished' },
      ],
    };
    const reused = await fetchHistoryGames(teamIds, previous, new Date('2026-09-12T00:00:00Z'));
    assert.deepEqual(calls, []);
    assert.deepEqual(reused.games.map((g) => g.id), ['a', 'b', 'c']);
    assert.deepEqual(reused.seasons, ['2025-26', '2024-25', '2023-24']);

    // 2) 기록이 없으면 받아 오고, 완료한 시즌만 표시한다
    calls.length = 0;
    global.fetch = async (url) => {
      calls.push(url);
      const day = String(url).match(/dates=(\d{8})/)?.[1] ?? '';
      if (day.startsWith('202411')) return respond(null, false); // 2024-25 시즌만 일부 실패
      return respond({ events: day === '20251015' ? [game('new', '2025-10-17T01:00Z')] : [] });
    };
    const fetched = await fetchHistoryGames(teamIds, { games: [] }, new Date('2026-09-12T00:00:00Z'));
    assert.ok(calls.length > 100, `구간 요청이 있어야 한다: ${calls.length}`);
    assert.deepEqual(fetched.games.map((g) => g.id), ['new']);
    // 요청이 실패한 2024-25는 완료로 표시하지 않아 다음 실행에서 다시 받는다
    assert.deepEqual(fetched.seasons, ['2025-26', '2023-24']);
  } finally {
    global.fetch = originalFetch;
  }
});
