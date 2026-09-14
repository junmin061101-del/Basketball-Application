'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs/promises');
const os = require('os');
const path = require('path');

const { archiveLeague, planArchive } = require('../../tools/archive-boxscores');

const game = (id, startTime, status = 'finished') => ({ id, startTime, status });

test('끝난 경기 중 보관소에 없는 것을 최근 경기부터 한도만큼 고른다', () => {
  const games = [
    game('a', '2024-01-01T00:00Z'),
    game('b', '2025-01-01T00:00Z'),
    game('c', '2026-01-01T00:00Z'),
    game('d', '2026-02-01T00:00Z', 'scheduled'),
  ];
  assert.deepEqual(planArchive(games, new Set(['c']), 5).map((g) => g.id), ['b', 'a']);
  assert.deepEqual(planArchive(games, new Set(), 1).map((g) => g.id), ['c']);
});

async function setup() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'archive-'));
  const archive = path.join(root, 'archive');
  const dist = path.join(root, 'dist');
  await fs.mkdir(path.join(archive, 'nba', 'boxscores'), { recursive: true });
  await fs.mkdir(path.join(dist, 'nba', 'boxscores'), { recursive: true });
  const put = (dir, id, lines) =>
    fs.writeFile(path.join(dir, 'nba', 'boxscores', `${id}.json`), JSON.stringify({ gameId: id, lines }));
  const line = (name) => [{ playerId: '1', name, points: 10 }];
  return { root, archive, dist, put, line };
}

test('수집기 결과는 보관하고, 없는 경기는 받고, 보관소 파일은 배포에 복사한다', async () => {
  const { archive, dist, put, line } = await setup();
  await fs.writeFile(
    path.join(dist, 'nba', 'games.json'),
    JSON.stringify({
      games: [
        game('old', '2024-01-01T00:00Z'), // 보관소에 있음 → 배포에 복사
        game('fresh', '2026-04-01T00:00Z'), // 수집기가 이번에 받음 → 보관
        game('missing', '2025-01-01T00:00Z'), // 없음 → 새로 받음
        game('live', '2026-09-13T00:00Z', 'live'), // 끝나지 않음 → 보관 안 함
      ],
    }),
  );
  await put(archive, 'old', line('Old Player'));
  await put(dist, 'fresh', line('Fresh Player'));
  await put(dist, 'live', line('Live Player'));

  const asked = [];
  const summary = await archiveLeague({
    league: 'nba',
    archiveRoot: archive,
    distRoot: dist,
    limit: 10,
    fetchBoxScore: async (id) => {
      asked.push(id);
      return { gameId: id, lines: [{ playerId: '9', name: 'LeBron James', points: 30 }] };
    },
    rename: (l) => (l.playerId === '9' ? '르브론 제임스' : l.name),
    now: () => 'T',
  });

  assert.deepEqual(asked, ['missing']);
  const archivedIds = (await fs.readdir(path.join(archive, 'nba', 'boxscores'))).sort();
  assert.deepEqual(archivedIds, ['fresh.json', 'missing.json', 'old.json']);
  const distIds = (await fs.readdir(path.join(dist, 'nba', 'boxscores'))).sort();
  assert.deepEqual(distIds, ['fresh.json', 'live.json', 'missing.json', 'old.json']);
  const missing = JSON.parse(await fs.readFile(path.join(dist, 'nba', 'boxscores', 'missing.json'), 'utf8'));
  assert.equal(missing.lines[0].name, '르브론 제임스'); // 사전 이름으로 바꿔 둔다
  assert.deepEqual(
    { archived: summary.archived, copiedIn: summary.copiedIn, fetched: summary.fetched, missing: summary.missing },
    { archived: 3, copiedIn: 1, fetched: 1, missing: 0 },
  );
});

test('연달아 실패하면 그 실행은 멈추고, 받은 만큼만 보관한다', async () => {
  const { archive, dist } = await setup();
  const games = Array.from({ length: 40 }, (_, i) => game(`g${i}`, `2025-01-${String((i % 28) + 1).padStart(2, '0')}T00:00Z`));
  await fs.writeFile(path.join(dist, 'nba', 'games.json'), JSON.stringify({ games }));
  let calls = 0;
  const summary = await archiveLeague({
    league: 'nba',
    archiveRoot: archive,
    distRoot: dist,
    limit: 40,
    concurrency: 1,
    fetchBoxScore: async () => {
      calls += 1;
      throw new Error('HTTP 403');
    },
  });
  assert.equal(calls, 20);
  assert.equal(summary.fetched, 0);
  assert.equal(summary.missing, 40);
});
