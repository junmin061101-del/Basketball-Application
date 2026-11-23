#!/usr/bin/env node
'use strict';

/**
 * 그날 마지막 경기가 끝나면 하룻밤 결과 캐러셀을 인스타(@baskit_official)에 한 번 올린다.
 *
 *   node tools/instagram/post.js <instagram 브랜치 작업 폴더>
 *
 * 리그(KBL·NBA)마다 경기가 시작된 가장 최근 날짜를 보고, 그날 경기가 모두 끝났고
 * (어제·오늘 경기만) 아직 안 올렸으면 cards.js로 카드를 그린다. 인스타는 공개 URL에서
 * 사진을 가져가므로 카드를 instagram 브랜치에 올리고, 게시한 뒤 그 브랜치의
 * posted.json에 적는다. 이 파일이 유일한 "올렸다" 기록이라 몇 번을 돌아도 한 번만 올린다.
 *
 * 환경변수: IG_ACCESS_TOKEN(시스템 사용자 토큰). POST_DRY_RUN=1이면 그리기만 한다.
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { KINDS, render, nightComplete, getJson, short, kstLabel, kstDay } = require('./cards');

const IG_USER = '17841475895149180'; // @baskit_official (공개 값)
const GRAPH = 'https://graph.facebook.com';
const REPO = process.env.GITHUB_REPOSITORY ?? 'junmin061101-del/Basketball-Application';
const BRANCH = 'instagram';

const LEAGUES = {
  kbl: {
    async load() {
      const [{ games }, { teams }] = await Promise.all([getJson('kbl/games'), getJson('kbl/teams')]);
      const names = Object.fromEntries(teams.map((t) => [t.id, short(t)]));
      return {
        games: [...games].sort((a, b) => a.startTime.localeCompare(b.startTime)),
        dayOf: (g) => kstDay(new Date(g.startTime)),
        today: kstDay(new Date()),
        name: (id) => names[id],
      };
    },
    title: (date) => `${kstLabel(new Date(`${date}T12:00:00+09:00`))} KBL 경기 결과`,
    tags: '#KBL #프로농구 #한국농구 #농구 #Baskit',
  },
  nba: {
    async load() {
      const [{ games }, { teams }] = await Promise.all([getJson('nba/games'), getJson('nba/teams')]);
      const names = Object.fromEntries(teams.map((t) => [t.id, t.name]));
      return {
        games,
        dayOf: (g) => g.date, // 미국 현지 날짜
        today: new Date().toISOString().slice(0, 10),
        name: (id) => names[id],
      };
    },
    title: (date) => `NBA 경기 결과 (미국 현지 ${Number(date.slice(5, 7))}.${Number(date.slice(8))})`,
    tags: '#NBA #NBA결과 #농구 #Baskit',
  },
};

/**
 * 올릴 날짜: 경기가 시작된 가장 최근 날짜가 어제·오늘이고, 그날 경기가 다 끝났고,
 * 아직 안 올렸으면 그 날짜. 아니면 null. 다음 날 경기가 시작되면 지난 날은 넘긴다.
 * ponytail: 연기된 경기가 "진행 중"으로 남으면 그날은 올라가지 않는다. 생기면 손으로 올린다.
 */
function dueDate(league, { games, dayOf, today }, posted) {
  const day = games.filter((g) => g.status !== 'scheduled').map(dayOf).sort().at(-1);
  const yesterday = new Date(Date.parse(today) - 864e5).toISOString().slice(0, 10);
  if (!day || day < yesterday || posted[`${league}-${day}`]) return null;
  return nightComplete(games.filter((g) => dayOf(g) === day)) ? day : null;
}

function caption(cfg, data, date, part, parts) {
  const lines = data.games
    .filter((g) => data.dayOf(g) === date && g.status === 'finished')
    .map((g) => `${data.name(g.homeTeamId)} ${g.homeScore} : ${g.awayScore} ${data.name(g.awayTeamId)}`);
  const head = `🏀 ${cfg.title(date)}${parts > 1 ? ` (${part}/${parts})` : ''}`;
  return [head, '', ...lines, '', cfg.tags].join('\n');
}

// ---------------------------------------------------------------- 인스타 게시 API

async function graph(method, endpoint, params = {}) {
  const query = new URLSearchParams({ ...params, access_token: process.env.IG_ACCESS_TOKEN });
  const res = await fetch(method === 'GET' ? `${GRAPH}/${endpoint}?${query}` : `${GRAPH}/${endpoint}`, {
    method,
    body: method === 'GET' ? undefined : query,
    signal: AbortSignal.timeout(30000),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || json.error) throw new Error(`${endpoint}: ${json.error?.message ?? `HTTP ${res.status}`}`);
  return json;
}

/** 컨테이너가 사진을 다 받아 갈 때까지 기다린다. */
async function ready(id) {
  for (let i = 0; i < 30; i++) {
    const { status_code: status } = await graph('GET', id, { fields: 'status_code' });
    if (status === 'FINISHED') return;
    if (status === 'ERROR' || status === 'EXPIRED') throw new Error(`컨테이너 ${id}: ${status}`);
    await new Promise((r) => setTimeout(r, 3000));
  }
  throw new Error(`컨테이너 ${id}: 시간 초과`);
}

/** 사진 URL들 → 게시물 하나(2장 이상이면 캐러셀). 반환: 게시물 id. */
async function publish(urls, text) {
  let id;
  if (urls.length === 1) {
    ({ id } = await graph('POST', `${IG_USER}/media`, { image_url: urls[0], caption: text }));
  } else {
    const children = [];
    for (const url of urls) children.push((await graph('POST', `${IG_USER}/media`, { image_url: url, is_carousel_item: 'true' })).id);
    for (const c of children) await ready(c);
    ({ id } = await graph('POST', `${IG_USER}/media`, { media_type: 'CAROUSEL', children: children.join(','), caption: text }));
  }
  await ready(id);
  return (await graph('POST', `${IG_USER}/media_publish`, { creation_id: id })).id;
}

// ---------------------------------------------------------------- 브랜치(사진 주소 + 게시 기록)

function commit(dir, message) {
  const git = (...args) => execFileSync('git', ['-C', dir, ...args], { stdio: 'inherit' });
  git('add', '-A');
  try {
    git('diff', '--cached', '--quiet');
    return; // 바뀐 게 없다
  } catch {}
  git('commit', '-q', '-m', message);
  git('push', '-q', 'origin', `HEAD:${BRANCH}`);
}

async function main() {
  const dir = process.argv[2];
  const dry = process.env.POST_DRY_RUN === '1';
  if (!dir) throw new Error('사용: node tools/instagram/post.js <instagram 브랜치 작업 폴더>');
  if (!dry && !process.env.IG_ACCESS_TOKEN) throw new Error('IG_ACCESS_TOKEN이 없어요');
  const logFile = path.join(dir, 'posted.json');
  const posted = fs.existsSync(logFile) ? JSON.parse(fs.readFileSync(logFile, 'utf8')) : {};
  const save = (message) => {
    fs.writeFileSync(logFile, `${JSON.stringify(posted, null, 2)}\n`);
    commit(dir, message);
  };

  let failed = false;
  for (const [league, cfg] of Object.entries(LEAGUES)) {
    try {
      const data = await cfg.load();
      const date = dueDate(league, data, posted);
      if (!date) {
        console.log(`${league}: 올릴 게 없어요`);
        continue;
      }
      const prefix = `${league}-${date}`;
      const files = await render(await KINDS[`${league}-night`](date));
      // toPosts가 붙인 이름 "<prefix>-p1-01.jpg"로 게시물을 나눈다.
      const parts = Object.values(Object.groupBy(files, (f) => f.match(/-p(\d+)-\d+\.jpg$/)[1]));
      for (const [i, part] of parts.entries()) {
        const key = `${prefix}-p${i + 1}`;
        if (posted[key]) continue; // 지난 실행이 이 게시물까지는 올렸다
        const text = caption(cfg, data, date, i + 1, parts.length);
        if (dry) {
          console.log(`\n[${key}] ${part.join(', ')}\n${text}`);
          continue;
        }
        fs.mkdirSync(path.join(dir, prefix), { recursive: true });
        for (const f of part) fs.copyFileSync(f, path.join(dir, prefix, path.basename(f)));
        commit(dir, `카드 ${key}`);
        const urls = part.map((f) => `https://raw.githubusercontent.com/${REPO}/${BRANCH}/${prefix}/${path.basename(f)}`);
        posted[key] = await publish(urls, text);
        save(`인스타 게시 ${key}`);
        console.log(`${key}: 게시함 (${posted[key]})`);
      }
      if (!dry) {
        posted[prefix] = new Date().toISOString();
        save(`인스타 게시 완료 ${prefix}`);
      }
    } catch (e) {
      console.error(`${league} 실패: ${e.message}`);
      failed = true;
    }
  }
  if (failed) process.exitCode = 1;
}

if (require.main === module) {
  main().catch((e) => {
    console.error('실패:', e.message);
    process.exit(1);
  });
}

module.exports = { dueDate, caption };
