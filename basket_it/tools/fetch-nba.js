#!/usr/bin/env node
'use strict';

/**
 * NBA 경기 결과를 모아 정적 JSON으로 떨어뜨린다(인스타 카드용).
 *
 * BALLDONTLIE API(무료 요금제: 경기·팀). 약관이 데이터 게시·상업 이용을 허용한다.
 * 리그 공식 데이터라고 말하거나 리그·팀 로고를 쓰면 안 된다. 무료는 1분에 5번이라
 * 실행마다 한 번(최근 5일 ~ 앞으로 2일)만 부른다. 무료 데이터는 늦게 갱신될 수 있어
 * 카드는 "Final"로 확정된 경기만 쓴다.
 *
 * 필요한 환경변수: NBA_API_KEY
 * 사용법: node tools/fetch-nba.js <출력 디렉터리>   → games.json, teams.json
 */

const fs = require('fs/promises');
const path = require('path');

const API = 'https://api.balldontlie.io/v1';

/** 팀 약어 → 한국어 이름(네이버 스포츠 표기)과 팀색. 로고는 쓰지 않는다. */
const TEAMS = {
  ATL: ['애틀랜타', '#E03A3E'], BOS: ['보스턴', '#007A33'], BKN: ['브루클린', '#6B7280'],
  CHA: ['샬럿', '#00788C'], CHI: ['시카고', '#CE1141'], CLE: ['클리블랜드', '#860038'],
  DAL: ['댈러스', '#00538C'], DEN: ['덴버', '#0E2240'], DET: ['디트로이트', '#C8102E'],
  GSW: ['골든스테이트', '#1D428A'], HOU: ['휴스턴', '#CE1141'], IND: ['인디애나', '#002D62'],
  LAC: ['LA 클리퍼스', '#C8102E'], LAL: ['LA 레이커스', '#552583'], MEM: ['멤피스', '#5D76A9'],
  MIA: ['마이애미', '#98002E'], MIL: ['밀워키', '#00471B'], MIN: ['미네소타', '#236192'],
  NOP: ['뉴올리언스', '#85714D'], NYK: ['뉴욕', '#006BB6'], OKC: ['오클라호마시티', '#007AC1'],
  ORL: ['올랜도', '#0077C0'], PHI: ['필라델피아', '#006BB6'], PHX: ['피닉스', '#E56020'],
  POR: ['포틀랜드', '#E03A3E'], SAC: ['새크라멘토', '#5A2D81'], SAS: ['샌안토니오', '#8A8D8F'],
  TOR: ['토론토', '#CE1141'], UTA: ['유타', '#002B5C'], WAS: ['워싱턴', '#002B5C'],
};

const day = (ms) => new Date(ms).toISOString().slice(0, 10);

/** API 경기 한 건 → 우리 모양. 모르는 팀(올스타전 등)이면 null. */
function toGame(g) {
  const home = g.home_team?.abbreviation;
  const away = g.visitor_team?.abbreviation;
  if (!TEAMS[home] || !TEAMS[away]) return null;
  const status = g.status === 'Final' ? 'finished' : /^\d{4}-\d{2}-\d{2}T/.test(g.status) ? 'scheduled' : 'live';
  return {
    id: String(g.id),
    date: g.date, // 미국 현지 날짜
    startTime: g.datetime ?? (status === 'scheduled' ? g.status : null),
    homeTeamId: home,
    awayTeamId: away,
    homeScore: g.home_team_score ?? 0,
    awayScore: g.visitor_team_score ?? 0,
    status,
    postseason: Boolean(g.postseason),
    quarters: quarters(g),
  };
}

/** 쿼터별 점수(1~4쿼터 + 연장). API가 주지 않으면 null(카드에서 뺀다). */
function quarters(g) {
  const pick = (side) =>
    ['q1', 'q2', 'q3', 'q4', 'ot1', 'ot2', 'ot3'].map((k) => g[`${side}_${k}`]).filter((v) => typeof v === 'number');
  const home = pick('home');
  const away = pick('visitor');
  return home.length >= 4 && home.length === away.length ? { home, away } : null;
}

async function main() {
  const outDir = process.argv[2];
  const key = process.env.NBA_API_KEY;
  if (!outDir || !key) {
    console.error('사용: NBA_API_KEY=... node tools/fetch-nba.js <출력 디렉터리>');
    process.exit(1);
  }
  const now = Date.now();
  const url = `${API}/games?start_date=${day(now - 5 * 864e5)}&end_date=${day(now + 2 * 864e5)}&per_page=100`;
  const res = await fetch(url, { headers: { Authorization: key }, signal: AbortSignal.timeout(20000) });
  if (!res.ok) throw new Error(`BALLDONTLIE HTTP ${res.status}`); // 키 값은 출력하지 않는다
  const { data = [] } = await res.json();
  const games = data.map(toGame).filter(Boolean).sort((a, b) => (a.startTime ?? a.date).localeCompare(b.startTime ?? b.date));

  await fs.mkdir(outDir, { recursive: true });
  const generatedAt = new Date().toISOString();
  await fs.writeFile(path.join(outDir, 'games.json'), JSON.stringify({ generated_at: generatedAt, source: 'balldontlie', games }));
  await fs.writeFile(
    path.join(outDir, 'teams.json'),
    JSON.stringify({ teams: Object.entries(TEAMS).map(([id, [name, color]]) => ({ id, name, color })) }),
  );
  console.log(`NBA 경기 ${games.length}개 (종료 ${games.filter((g) => g.status === 'finished').length})`);
}

if (require.main === module) {
  main().catch((e) => {
    console.error('NBA 수집 실패:', e.message);
    process.exit(1);
  });
}

module.exports = { toGame, TEAMS };
