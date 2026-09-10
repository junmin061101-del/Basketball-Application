#!/usr/bin/env node
'use strict';

/**
 * ESPN 공개 API에서 NBA 데이터를 모아 정적 JSON으로 떨어뜨린다.
 *
 * 팀·순위·일정·로스터를 내려주는 site.api.espn.com에는 CORS 헤더가 없어
 * 브라우저에서 직접 못 부른다. 그래서 뉴스와 같은 방식으로 GitHub Actions가
 * 미리 받아 GitHub Pages에 올려두고, 앱은 그 파일만 읽는다.
 *
 * 선수 개인 시즌 스탯(site.web.api.espn.com)과 선수 사진(a.espncdn.com)은
 * CORS가 열려 있어 앱이 필요할 때 직접 부른다. 500명이 넘는 선수 스탯을
 * 미리 받아둘 이유가 없다.
 *
 * 사용법: node tools/fetch-nba.js <출력 디렉터리>
 */

const fs = require('fs/promises');
const path = require('path');

const SITE = 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba';
const CORE = 'https://site.api.espn.com/apis/v2/sports/basketball/nba';

/**
 * 일정을 앞뒤로 며칠씩 훑을지.
 *
 * 앞쪽은 최근 전적, 뒤쪽은 다음 경기를 위해서다. 비시즌에는 몇 주 뒤에야
 * 첫 경기가 있으므로 뒤쪽을 넉넉히 잡는다.
 */
const PAST_DAYS = 14;
const FUTURE_DAYS = 45;

/**
 * 한 번에 요청할 날짜 폭.
 *
 * 스코어보드는 날짜 범위를 받아 한 번에 최대 100경기를 준다. 시즌 중에는
 * 하루 최대 15경기쯤이라 5일씩 끊으면 상한에 걸리지 않는다.
 */
const CHUNK_DAYS = 5;

/**
 * ESPN 포지션 약어 → 앱의 PlayerPosition.
 *
 * ESPN 로스터는 G / F / C 세 가지만 준다. 앱의 enum은 다섯 가지라 그대로는
 * 못 채우므로, 정렬·분류에 쓸 대표값만 여기서 정하고 화면에 보여줄 문구는
 * positionLabel로 따로 내려보낸다. "가드"를 "포인트가드"라고 적으면 안 된다.
 */
const POSITION_BY_ABBR = {
  PG: 'pg',
  SG: 'sg',
  SF: 'sf',
  PF: 'pf',
  C: 'c',
  G: 'pg',
  F: 'sf',
};

/** 화면에 그대로 보여줄 포지션 이름. */
const POSITION_LABEL_BY_ABBR = {
  PG: '포인트가드',
  SG: '슈팅가드',
  SF: '스몰포워드',
  PF: '파워포워드',
  C: '센터',
  G: '가드',
  F: '포워드',
};

async function getJson(url) {
  // User-Agent를 붙이면 ESPN 방화벽이 403으로 막는다(봇 UA도, 브라우저 UA도).
  // 기본값 그대로 두는 편이 통과한다.
  const res = await fetch(url, { signal: AbortSignal.timeout(20000) });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
  return res.json();
}

/** ESPN 팀 → 앱 Team. 도시와 팀명을 갈라 담는다. */
function toTeam(t) {
  // displayName "Los Angeles Lakers", name "Lakers" → city는 그 차이.
  const full = t.displayName ?? '';
  const name = t.name ?? '';
  const city = full.endsWith(name) ? full.slice(0, full.length - name.length).trim() : full;
  return {
    id: t.id,
    city,
    name,
    shortName: t.abbreviation ?? name,
    // ESPN은 "552583" 같은 헥사값을 #없이 준다.
    color: `#${(t.color ?? '1D428A').replace(/^#/, '').toUpperCase()}`,
    logo: t.logos?.[0]?.href ?? null,
  };
}

async function fetchTeams() {
  const body = await getJson(`${SITE}/teams`);
  const entries = body.sports?.[0]?.leagues?.[0]?.teams ?? [];
  return entries.map((e) => toTeam(e.team)).filter((t) => t.id);
}

function statValue(stats, name) {
  const found = (stats ?? []).find((s) => s.name === name);
  return found?.value ?? null;
}

async function fetchStandings() {
  const body = await getJson(`${CORE}/standings`);
  const rows = [];
  for (const conference of body.children ?? []) {
    for (const entry of conference.standings?.entries ?? []) {
      const wins = statValue(entry.stats, 'wins');
      const losses = statValue(entry.stats, 'losses');
      if (wins == null || losses == null) continue;
      const gb = statValue(entry.stats, 'gamesBehind');
      rows.push({
        teamId: entry.team.id,
        wins: Math.round(wins),
        losses: Math.round(losses),
        // "-"로 오는 선두는 0으로 둔다.
        gamesBehind: typeof gb === 'number' ? gb : 0,
        conference: conference.name ?? '',
      });
    }
  }
  // 승률 내림차순. 앱의 순위표가 이 순서를 그대로 쓴다.
  rows.sort((a, b) => {
    const pa = a.wins / Math.max(1, a.wins + a.losses);
    const pb = b.wins / Math.max(1, b.wins + b.losses);
    return pb - pa;
  });
  return rows;
}

/** ESPN 경기 상태 → 앱 GameStatus. */
function toStatus(type) {
  if (type?.completed) return 'finished';
  if (type?.state === 'in') return 'live';
  return 'scheduled';
}

function yyyymmdd(d) {
  return (
    d.getUTCFullYear().toString() +
    String(d.getUTCMonth() + 1).padStart(2, '0') +
    String(d.getUTCDate()).padStart(2, '0')
  );
}

async function fetchGames(teamIds) {
  const today = new Date();
  const games = [];
  const seen = new Set();

  for (
    let offset = -PAST_DAYS;
    offset <= FUTURE_DAYS;
    offset += CHUNK_DAYS
  ) {
    const from = new Date(today);
    from.setUTCDate(from.getUTCDate() + offset);
    const to = new Date(today);
    to.setUTCDate(
      to.getUTCDate() + Math.min(offset + CHUNK_DAYS - 1, FUTURE_DAYS),
    );
    const range = `${yyyymmdd(from)}-${yyyymmdd(to)}`;

    try {
      const body = await getJson(`${SITE}/scoreboard?limit=100&dates=${range}`);
      for (const event of body.events ?? []) {
        if (seen.has(event.id)) continue;
        seen.add(event.id);
        const competition = event.competitions?.[0];
        if (!competition) continue;
        const home = competition.competitors?.find((c) => c.homeAway === 'home');
        const away = competition.competitors?.find((c) => c.homeAway === 'away');
        if (!home || !away) continue;

        // 프리시즌에는 NBA 소속이 아닌 해외 구단과의 경기가 섞여 온다.
        // 앱이 팀 정보를 못 찾으므로 아예 담지 않는다.
        if (!teamIds.has(home.team.id) || !teamIds.has(away.team.id)) continue;

        const status = toStatus(competition.status?.type);
        games.push({
          id: event.id,
          startTime: event.date,
          homeTeamId: home.team.id,
          awayTeamId: away.team.id,
          homeScore: Number(home.score ?? 0),
          awayScore: Number(away.score ?? 0),
          status,
          // "3rd Quarter 07:12" 같은 진행 상황.
          liveClock:
            status === 'live'
              ? competition.status?.type?.shortDetail ?? null
              : null,
        });
      }
    } catch (error) {
      // 한 구간이 실패해도 나머지 날짜는 살린다.
      console.warn(`  일정 실패 ${range}: ${error.message}`);
    }
  }
  games.sort((a, b) => a.startTime.localeCompare(b.startTime));
  return games;
}

async function fetchRosters(teams) {
  const players = [];
  for (const team of teams) {
    try {
      const body = await getJson(`${SITE}/teams/${team.id}/roster`);
      for (const a of body.athletes ?? []) {
        const abbr = a.position?.abbreviation ?? '';
        players.push({
          id: a.id,
          name: a.displayName ?? a.fullName ?? '',
          teamId: team.id,
          position: POSITION_BY_ABBR[abbr] ?? 'sf',
          positionLabel: POSITION_LABEL_BY_ABBR[abbr] ?? null,
          backNumber: Number(a.jersey ?? 0) || 0,
          headshot: a.headshot?.href ?? null,
          height: a.displayHeight ?? null,
          weight: a.displayWeight ?? null,
          college: a.college?.name ?? null,
          birthDate: a.dateOfBirth ?? null,
        });
      }
    } catch (error) {
      console.warn(`  로스터 실패 ${team.shortName}: ${error.message}`);
    }
  }
  return players;
}

async function main() {
  const outDir = process.argv[2];
  if (!outDir) {
    console.error('사용법: node tools/fetch-nba.js <출력 디렉터리>');
    process.exit(1);
  }

  console.log('NBA 팀 수집...');
  const teams = await fetchTeams();
  console.log(`  ${teams.length}개 팀`);
  // 팀을 못 받으면 나머지도 의미가 없다. 기존 파일을 덮어쓰지 않고 멈춘다.
  if (teams.length === 0) {
    console.error('팀 목록이 비었습니다. 기존 데이터를 지우지 않기 위해 중단합니다.');
    process.exit(1);
  }

  console.log('순위 수집...');
  const standings = await fetchStandings().catch((e) => {
    console.warn(`  순위 실패: ${e.message}`);
    return [];
  });
  console.log(`  ${standings.length}개 항목`);

  console.log('일정 수집...');
  const games = await fetchGames(new Set(teams.map((t) => t.id)));
  console.log(`  ${games.length}경기`);

  console.log('로스터 수집...');
  const players = await fetchRosters(teams);
  console.log(`  ${players.length}명`);

  await fs.mkdir(outDir, { recursive: true });
  const generatedAt = new Date().toISOString();
  const files = { teams, standings, games, players };
  for (const [name, data] of Object.entries(files)) {
    const file = path.join(outDir, `${name}.json`);
    await fs.writeFile(
      file,
      JSON.stringify({ generated_at: generatedAt, [name]: data }),
    );
    console.log(`${file}: ${data.length}건`);
  }
}

main().catch((error) => {
  console.error('NBA 수집 실패:', error.message);
  process.exit(1);
});
