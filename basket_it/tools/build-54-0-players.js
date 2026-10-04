#!/usr/bin/env node
'use strict';

/**
 * 미니게임 "54-0"에 쓸 선수 명단을 만든다.
 *
 * KBL 공식 API에는 1997년 원년부터 시즌마다 선수별 기록이 남아 있다. 그걸 그대로
 * 받아 [구단 · 시대]로 묶어 둔다. 선수도 기록도 지어내지 않는다.
 *
 *   node tools/build-54-0-players.js assets/game/kbl_players_54_0.json
 *
 * 팀 코드(tcode)는 시즌마다 달라져서 쓸 수 없고, 팀 이름으로 지금 구단을 찾는다.
 * KBL 구단은 이름을 여러 번 바꿨지만 연고와 운영 주체가 이어지는 하나의 구단이다.
 */

const fs = require('fs/promises');
const path = require('path');

const API = 'https://api.kbl.or.kr';
const HEADERS = {
  Channel: 'WEB',
  TeamCode: 'XX',
  lang: 'ko',
  'X-Requested-With': 'XMLHttpRequest',
};

/**
 * 역대 팀 이름 → 지금 구단 id.
 *
 * 왼쪽이 이름에 들어 있으면 그 구단으로 본다(긴 이름을 먼저 본다).
 * 상무(국군체육부대)는 정식 구단이 아니어서 넣지 않는다.
 */
const TEAM_LINEAGE = [
  ['현대모비스', 'mobis'],
  ['모비스', 'mobis'],
  ['기아', 'mobis'], // 부산 기아 엔터프라이즈 → 울산 모비스
  ['한국가스공사', 'kogas'],
  ['가스공사', 'kogas'],
  ['전자랜드', 'kogas'], // 인천 전자랜드 → 대구 한국가스공사
  ['빅스', 'kogas'], // 인천 신세기/SK 빅스
  ['대우', 'kogas'], // 인천 대우 제우스
  ['정관장', 'kgc'],
  ['인삼공사', 'kgc'],
  ['KT&G', 'kgc'],
  ['SBS', 'kgc'], // 안양 SBS 스타즈 → 안양 KT&G
  ['KTF', 'kt'],
  ['코리아텐더', 'kt'], // 여수 코리아텐더 → 부산 KTF
  ['KT', 'kt'],
  ['KCC', 'kcc'],
  ['현대', 'kcc'], // 대전 현대 다이냇 → 전주 KCC ("현대모비스"를 먼저 걸러 둔다)
  ['삼보', 'db'], // 원주 TG삼보
  ['동부', 'db'],
  ['나래', 'db'], // 원주 나래 블루버드
  ['DB', 'db'],
  ['소노', 'sono'],
  ['캐롯', 'sono'],
  ['오리온', 'sono'], // 대구 동양 → 고양 오리온 → 캐롯 → 소노
  ['동양', 'sono'],
  ['삼성', 'samsung'],
  ['SK', 'sk'],
  ['LG', 'lg'],
];

/** 뛴 기록이 너무 적은 선수는 넣지 않는다(게임이 심심해진다). */
const MIN_GAMES = 10;
const MIN_MINUTES_PER_GAME = 10;

function teamIdOf(name) {
  const s = String(name ?? '');
  for (const [keyword, id] of TEAM_LINEAGE) {
    if (s.includes(keyword)) return id;
  }
  return null;
}

/** KBL 포지션 표기(GD/FD/C) → 게임이 쓰는 큰 분류. */
function positionOf(pos) {
  switch (String(pos ?? '').toUpperCase()) {
    case 'GD':
      return 'G';
    case 'FD':
    case 'F':
      return 'F';
    case 'C':
      return 'C';
    default:
      return null;
  }
}

/** 시즌 이름("2005-2006") → 시작 연도. */
function startYear(seasonName) {
  const m = String(seasonName ?? '').match(/^(\d{4})/);
  return m ? Number(m[1]) : null;
}

async function kblGet(pathname, params = {}) {
  const query = new URLSearchParams(params).toString();
  const res = await fetch(`${API}${pathname}${query ? `?${query}` : ''}`, {
    headers: HEADERS,
    signal: AbortSignal.timeout(30000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${pathname}`);
  return res.json();
}

/** 한 시즌의 선수 기록 → 게임용 줄. */
function toEntries(rows, season) {
  const year = startYear(season.seasonName);
  if (year == null) return [];
  const era = Math.floor(year / 10) * 10;
  const entries = [];
  for (const row of Array.isArray(rows) ? rows : []) {
    const player = row.player ?? {};
    const r = row.records ?? {};
    const games = Number(row.gameCount) || 0;
    const teamId = teamIdOf(player.tname);
    const position = positionOf(player.pos);
    if (!teamId || !position || games < MIN_GAMES) continue;

    const minutes = (Number(r.playMin) || 0) + (Number(r.playSec) || 0) / 60;
    const perGame = (value) => Math.round(((Number(value) || 0) / games) * 10) / 10;
    if (minutes / games < MIN_MINUTES_PER_GAME) continue;

    entries.push({
      id: String(player.pcode),
      name: String(player.pname ?? '').trim(),
      position,
      teamId,
      era,
      season: String(season.seasonName),
      // 그때 그 팀 이름("부산기아"). 화면에 작게 적어 둔다.
      teamName: String(player.tname ?? '').trim(),
      games,
      starts: Number(row.startCount) || 0,
      mpg: perGame(minutes),
      ppg: perGame(r.score),
      rpg: perGame(r.rb),
      apg: perGame(r.ast),
      spg: perGame(r.stl),
      bpg: perGame(r.bs),
    });
  }
  return entries;
}

/** 같은 선수가 한 시대·한 구단에 여러 시즌 있으면 가장 많이 뛴 시즌만 남긴다. */
function pickBestSeasons(entries) {
  const best = new Map();
  for (const entry of entries) {
    const key = `${entry.id}:${entry.teamId}:${entry.era}`;
    const kept = best.get(key);
    if (!kept || entry.games * entry.mpg > kept.games * kept.mpg) {
      best.set(key, entry);
    }
  }
  return [...best.values()].sort(
    (a, b) => a.era - b.era || a.teamId.localeCompare(b.teamId) || b.ppg - a.ppg,
  );
}

async function main() {
  const out = process.argv[2];
  if (!out) {
    console.error('사용법: node tools/build-54-0-players.js <파일 경로>');
    process.exit(1);
  }

  const seasons = await kblGet('/season/list', {
    seasonCategory: 'R',
    gameCode: '01',
    seasonGrade: 1,
  });
  const started = seasons
    .filter((s) => String(s.gamedateStart) <= new Date().toISOString().slice(0, 10).replace(/-/g, ''))
    .sort((a, b) => String(a.gamedateStart).localeCompare(String(b.gamedateStart)));
  console.log(`시즌 ${started.length}개`);

  const all = [];
  for (const season of started) {
    try {
      const rows = await kblGet(`/leagues/${season.glkey}/stats/players`);
      const entries = toEntries(rows, season);
      all.push(...entries);
      console.log(`  ${season.seasonName}: ${entries.length}명`);
    } catch (error) {
      console.warn(`  ${season.seasonName}: 실패 (${error.message})`);
    }
  }

  const players = pickBestSeasons(all);
  const byEra = {};
  for (const p of players) byEra[p.era] = (byEra[p.era] ?? 0) + 1;

  await fs.mkdir(path.dirname(out), { recursive: true });
  await fs.writeFile(
    out,
    JSON.stringify({
      generated_at: new Date().toISOString(),
      source: 'KBL 공식 기록 (api.kbl.or.kr)',
      players,
    }),
  );
  console.log(`${out}: ${players.length}명`, byEra);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

module.exports = { TEAM_LINEAGE, pickBestSeasons, positionOf, teamIdOf, toEntries };
