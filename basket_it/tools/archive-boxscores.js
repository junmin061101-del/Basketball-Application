#!/usr/bin/env node
'use strict';

/**
 * 지난 경기 박스스코어 보관소.
 *
 * GitHub Pages는 실행마다 사이트를 통째로 새로 올린다. 그래서 수집기는
 * 최근 경기 박스스코어만 다시 받아 올리고, 지난 시즌 경기는 선수 기록이
 * 비어 있었다. 끝난 경기의 박스스코어는 바뀌지 않으므로 저장소의
 * boxscore-archive 브랜치에 한 번 받아 두고, 실행마다 그 파일을 사이트에
 * 함께 복사한다.
 *
 * 한 번 실행하면
 *   1. 이번에 수집기가 받은 끝난 경기 박스스코어를 보관소에 넣고
 *   2. 보관소에 없는 끝난 경기를 최근 경기부터 [한도]만큼 새로 받아 넣고
 *   3. 보관소 파일을 배포 디렉터리에 복사한다.
 * 한도가 있어 처음 채울 때는 여러 번에 걸쳐 채워진다.
 *
 * 사용법: node tools/archive-boxscores.js <보관소 디렉터리> <배포 디렉터리>
 * 환경변수: ARCHIVE_LIMIT_NBA(기본 400), ARCHIVE_LIMIT_KBL(기본 300)
 */

const fs = require('fs/promises');
const path = require('path');

/** 연달아 이만큼 실패하면(차단 등) 이번 실행은 그만 받는다. */
const MAX_CONSECUTIVE_FAILURES = 20;

async function readJson(file) {
  try {
    return JSON.parse(await fs.readFile(file, 'utf8'));
  } catch (_) {
    return null;
  }
}

async function listIds(dir) {
  try {
    const files = await fs.readdir(dir);
    return new Set(files.filter((f) => f.endsWith('.json')).map((f) => f.slice(0, -5)));
  } catch (_) {
    return new Set();
  }
}

/** 보관소에 새로 받아 넣을 끝난 경기. 최근 경기부터 [limit]개. */
function planArchive(games, have, limit) {
  return games
    .filter((g) => g.status === 'finished' && !have.has(g.id))
    .sort((a, b) => String(b.startTime).localeCompare(String(a.startTime)))
    .slice(0, limit);
}

/** [items]를 최대 [limit]개씩 동시에 처리한다. */
async function mapLimit(items, limit, fn) {
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const index = next;
      next += 1;
      await fn(items[index], index);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
}

/**
 * 리그 하나를 보관·복사한다. 네트워크(fetchBoxScore)와 이름 바꾸기(rename)는
 * 인자로 받아 테스트에서 가짜로 바꾼다.
 */
async function archiveLeague({
  league,
  archiveRoot,
  distRoot,
  fetchBoxScore,
  limit,
  concurrency = 4,
  rename = (line) => line.name,
  now = () => new Date().toISOString(),
}) {
  const games = (await readJson(path.join(distRoot, league, 'games.json')))?.games;
  if (!Array.isArray(games)) {
    console.warn(`${league}: games.json이 없어 건너뛴다`);
    return null;
  }
  const finished = new Set(games.filter((g) => g.status === 'finished').map((g) => g.id));
  const archiveDir = path.join(archiveRoot, league, 'boxscores');
  const distDir = path.join(distRoot, league, 'boxscores');
  await fs.mkdir(archiveDir, { recursive: true });
  await fs.mkdir(distDir, { recursive: true });

  const archived = await listIds(archiveDir);
  const fresh = await listIds(distDir);
  const write = (dir, box) =>
    fs.writeFile(
      path.join(dir, `${box.gameId}.json`),
      JSON.stringify({
        generated_at: now(),
        gameId: box.gameId,
        lines: box.lines.map((line) => ({ ...line, name: rename(line) })),
      }),
    );

  // 1. 수집기가 이번에 받은 끝난 경기 → 보관소
  let copiedIn = 0;
  for (const id of fresh) {
    if (!finished.has(id) || archived.has(id)) continue;
    const box = await readJson(path.join(distDir, `${id}.json`));
    if (!box?.lines?.length) continue;
    await write(archiveDir, { gameId: id, lines: box.lines });
    archived.add(id);
    copiedIn += 1;
  }

  // 2. 보관소에 없는 끝난 경기를 새로 받는다
  const targets = planArchive(games, archived, limit);
  let fetched = 0;
  let failed = 0;
  let consecutive = 0;
  let stopped = false;
  await mapLimit(targets, concurrency, async (game) => {
    if (stopped) return;
    try {
      const box = await fetchBoxScore(game.id);
      if (!box?.lines?.length) throw new Error('기록 없음');
      await write(archiveDir, box);
      archived.add(game.id);
      fetched += 1;
      consecutive = 0;
    } catch (error) {
      failed += 1;
      consecutive += 1;
      if (consecutive >= MAX_CONSECUTIVE_FAILURES && !stopped) {
        stopped = true;
        console.warn(`${league}: 연달아 ${consecutive}번 실패해 이번 실행은 멈춘다 (${error.message})`);
      }
    }
  });

  // 3. 보관소 → 배포 디렉터리(수집기가 새로 받은 파일은 덮지 않는다)
  let copiedOut = 0;
  for (const id of archived) {
    if (fresh.has(id)) continue;
    await fs.copyFile(path.join(archiveDir, `${id}.json`), path.join(distDir, `${id}.json`));
    copiedOut += 1;
  }

  const missing = games.filter((g) => g.status === 'finished' && !archived.has(g.id)).length;
  const summary = { league, archived: archived.size, copiedIn, fetched, failed, copiedOut, missing };
  console.log(
    `${league}: 보관 ${summary.archived}경기 (새로 받음 ${fetched}, 실패 ${failed}, ` +
      `수집기에서 ${copiedIn}), 배포에 복사 ${copiedOut}, 아직 없는 경기 ${missing}`,
  );
  return summary;
}

async function main() {
  const [archiveRoot, distRoot] = process.argv.slice(2);
  if (!archiveRoot || !distRoot) {
    console.error('사용법: node tools/archive-boxscores.js <보관소 디렉터리> <배포 디렉터리>');
    process.exit(1);
  }
  const nba = require('./fetch-nba');
  const kbl = require('./fetch-kbl');
  const { loadPlayerNames } = require('./nba-ko');
  // NBA 박스스코어 이름은 ESPN 영문이다. 앱 선수 명단에 없는 지난 선수도
  // 한국어로 보이도록 사전에 있는 이름은 바꿔 둔다.
  const koNames = loadPlayerNames();

  await archiveLeague({
    league: 'nba',
    archiveRoot,
    distRoot,
    fetchBoxScore: nba.fetchBoxScore,
    concurrency: nba.CONCURRENCY,
    limit: Number(process.env.ARCHIVE_LIMIT_NBA ?? 400),
    rename: (line) => koNames.get(line.playerId) ?? line.name,
  });
  await archiveLeague({
    league: 'kbl',
    archiveRoot,
    distRoot,
    fetchBoxScore: kbl.fetchBoxScore,
    concurrency: kbl.CONCURRENCY,
    limit: Number(process.env.ARCHIVE_LIMIT_KBL ?? 300),
  });
}

if (require.main === module) {
  main().catch((error) => {
    // 보관소가 실패해도 데이터 배포는 막지 않는다.
    console.error(`보관소 실패: ${error.message}`);
  });
}

module.exports = { archiveLeague, planArchive };
