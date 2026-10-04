#!/usr/bin/env node
'use strict';

/**
 * 미니게임 "54-0"에 쓸 선수 명단을 만든다.
 *
 *   node tools/build-54-0-players.js assets/game/kbl_players_54_0.json
 *   python3 tools/build-54-0-photos.py assets/game/kbl_players_54_0.json
 *
 * 두 번째 줄까지 돌려야 한다. 이 스크립트는 사진 여부(hasPhoto)를 지우므로,
 * 명단을 새로 만들면 사진 스크립트를 이어서 돌린다.
 *
 * 지금 KBL 10개 구단과 지금 뛰는 선수만 담는다. 옛날 선수는 이름을 알아보는
 * 사람이 적어서 게임이 되지 않는다.
 *
 * 기록은 "제대로 치른 가장 최근 시즌"의 경기당 평균을 쓴다. 시즌 초에는 한두
 * 경기 기록뿐이라 그걸로 선수를 평가할 수 없기 때문이다. 소속 팀은 이번 시즌
 * 기록이 있으면 그쪽(이적 반영), 없으면 기록을 가져온 시즌의 팀으로 한다.
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

/** 지금 구단 이름 → 앱 팀 id(lib/data/team_logo_assets.dart와 같은 id). */
const TEAMS = [
  ['한국가스공사', 'kogas'],
  ['현대모비스', 'mobis'],
  ['정관장', 'kgc'],
  ['소노', 'sono'],
  ['삼성', 'samsung'],
  ['KCC', 'kcc'],
  ['KT', 'kt'],
  ['DB', 'db'],
  ['SK', 'sk'],
  ['LG', 'lg'],
];

/** 벤치에서 잠깐 뛴 선수는 넣지 않는다(게임이 심심해진다). */
const MIN_GAMES = 10;
const MIN_MINUTES_PER_GAME = 10;

/** 기록을 가져올 시즌인지 가르는 기준. 이보다 적게 치렀으면 시즌 초다. */
const SEASON_READY_GAMES = 20;

function teamIdOf(name) {
  const s = String(name ?? '');
  for (const [keyword, id] of TEAMS) {
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

async function kblGet(pathname, params = {}) {
  const query = new URLSearchParams(params).toString();
  const res = await fetch(`${API}${pathname}${query ? `?${query}` : ''}`, {
    headers: HEADERS,
    signal: AbortSignal.timeout(30000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${pathname}`);
  return res.json();
}

/** 시즌 한 해의 선수 기록 → 게임용 줄. 기준에 못 미치는 선수는 뺀다. */
function toEntries(rows, seasonName) {
  const entries = [];
  for (const row of Array.isArray(rows) ? rows : []) {
    const player = row.player ?? {};
    const r = row.records ?? {};
    const games = Number(row.gameCount) || 0;
    const teamId = teamIdOf(player.tname);
    const position = positionOf(player.pos);
    if (!teamId || !position || games < MIN_GAMES) continue;

    const minutes = (Number(r.playMin) || 0) + (Number(r.playSec) || 0) / 60;
    if (minutes / games < MIN_MINUTES_PER_GAME) continue;
    const perGame = (value) => Math.round(((Number(value) || 0) / games) * 10) / 10;

    entries.push({
      id: String(player.pcode),
      name: String(player.pname ?? '').trim(),
      position,
      teamId,
      teamName: String(player.tname ?? '').trim(),
      season: String(seasonName),
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

/** 치른 경기가 가장 많은 선수의 경기 수. 시즌을 제대로 치렀는지 본다. */
function playedGames(rows) {
  return (Array.isArray(rows) ? rows : []).reduce(
    (most, row) => Math.max(most, Number(row.gameCount) || 0),
    0,
  );
}

async function main() {
  const out = process.argv[2];
  if (!out) {
    console.error('사용법: node tools/build-54-0-players.js <파일 경로>');
    process.exit(1);
  }

  const seasons = (
    await kblGet('/season/list', {
      seasonCategory: 'R',
      gameCode: '01',
      seasonGrade: 1,
    })
  ).sort((a, b) => String(b.gamedateStart).localeCompare(String(a.gamedateStart)));

  // 이번 시즌(소속 팀)과, 기록을 가져올 시즌을 찾는다.
  const current = seasons[0];
  const currentRows = await kblGet(`/leagues/${current.glkey}/stats/players`);
  let statSeason = current;
  let statRows = currentRows;
  for (const season of seasons) {
    const rows =
      season.glkey === current.glkey
        ? currentRows
        : await kblGet(`/leagues/${season.glkey}/stats/players`);
    if (playedGames(rows) >= SEASON_READY_GAMES) {
      statSeason = season;
      statRows = rows;
      break;
    }
  }
  console.log(`이번 시즌 ${current.seasonName} / 기록 ${statSeason.seasonName}`);

  // 이적한 선수는 이번 시즌 팀으로 바꾼다.
  const teamNow = new Map();
  for (const row of currentRows) {
    const id = String(row.player?.pcode ?? '');
    const name = String(row.player?.tname ?? '').trim();
    if (id && teamIdOf(name)) teamNow.set(id, name);
  }

  const players = toEntries(statRows, statSeason.seasonName).map((player) => {
    const now = teamNow.get(player.id);
    if (!now || now === player.teamName) return player;
    return { ...player, teamName: now, teamId: teamIdOf(now) };
  });
  players.sort((a, b) => a.teamId.localeCompare(b.teamId) || b.ppg - a.ppg);

  const byTeam = {};
  for (const p of players) byTeam[p.teamName] = (byTeam[p.teamName] ?? 0) + 1;

  await fs.mkdir(path.dirname(out), { recursive: true });
  await fs.writeFile(
    out,
    JSON.stringify({
      generated_at: new Date().toISOString(),
      source: 'KBL 공식 기록 (api.kbl.or.kr)',
      season: statSeason.seasonName,
      players,
    }),
  );
  console.log(`${out}: ${players.length}명`, byTeam);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}

module.exports = { TEAMS, positionOf, teamIdOf, toEntries };
