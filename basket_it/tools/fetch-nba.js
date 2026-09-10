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
const WEB = 'https://site.web.api.espn.com/apis/common/v3/sports/basketball/nba';
const ATHLETE = 'https://sports.core.api.espn.com/v2/sports/basketball/leagues/nba/athletes';

/**
 * 지난 실행에서 올려둔 결과. 드래프트와 끝난 경기의 박스스코어는 바뀌지
 * 않으므로 여기서 가져와 다시 쓴다. 매 실행마다 선수 557명을 새로 부르지
 * 않기 위해서다. 첫 실행이면 비어 있고, 그때는 전부 새로 받는다.
 */
const PREVIOUS_BASE = process.env.NBA_PREVIOUS_BASE_URL ?? '';

/** 동시에 보낼 요청 수. 8건 동시에 1초 남짓으로 막히지 않는 걸 확인했다. */
const CONCURRENCY = 8;

/** [items]를 최대 [limit]개씩 동시에 처리한다. 순서는 입력 순서를 지킨다. */
async function mapLimit(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const index = next;
      next += 1;
      results[index] = await fn(items[index], index);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

/** 지난 실행 결과를 읽는다. 없거나 실패하면 null. */
async function getPrevious(relativePath) {
  if (!PREVIOUS_BASE) return null;
  try {
    const res = await fetch(`${PREVIOUS_BASE}/${relativePath}`, {
      signal: AbortSignal.timeout(15000),
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (_) {
    return null;
  }
}

/** "3-5" → [3, 5]. */
function madeAttempted(value) {
  const [made, attempted] = String(value ?? '').split('-');
  return [Number(made) || 0, Number(attempted) || 0];
}

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
        pointsAgainst: statValue(entry.stats, 'avgPointsAgainst') ?? 0,
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

/**
 * 전 선수의 이번 시즌 평균. 스탯 리더에 쓴다.
 *
 * 선수별로 부르면 578번이지만 byathlete 엔드포인트는 limit을 크게 주면
 * 한 번에 전원을 준다. 로스터에서 빠진 선수(자유계약 등)도 여기에는 있어,
 * 그 선수들 이름·소속도 함께 돌려준다.
 */
async function fetchLeaders() {
  const body = await getJson(`${WEB}/statistics/byathlete?limit=1000`);
  const namesOf = {};
  for (const category of body.categories ?? []) {
    namesOf[category.name] = category.names ?? [];
  }

  const leaders = [];
  const athletes = [];
  for (const entry of body.athletes ?? []) {
    const a = entry.athlete ?? {};
    const valueOf = (categoryName, statName) => {
      const category = (entry.categories ?? []).find((c) => c.name === categoryName);
      const index = (namesOf[categoryName] ?? []).indexOf(statName);
      if (!category || index < 0) return 0;
      return Number(category.values?.[index]) || 0;
    };

    leaders.push({
      playerId: a.id,
      teamId: a.teamId ?? '',
      gamesPlayed: Math.round(valueOf('general', 'gamesPlayed')),
      minutes: valueOf('general', 'avgMinutes'),
      points: valueOf('offensive', 'avgPoints'),
      fgm: valueOf('offensive', 'avgFieldGoalsMade'),
      fga: valueOf('offensive', 'avgFieldGoalsAttempted'),
      tpm: valueOf('offensive', 'avgThreePointFieldGoalsMade'),
      tpa: valueOf('offensive', 'avgThreePointFieldGoalsAttempted'),
      ftm: valueOf('offensive', 'avgFreeThrowsMade'),
      fta: valueOf('offensive', 'avgFreeThrowsAttempted'),
      // 이 엔드포인트는 리바운드를 공격/수비로 나눠 주지 않는다. 총합만 담는다.
      reb: valueOf('general', 'avgRebounds'),
      ast: valueOf('offensive', 'avgAssists'),
      tov: valueOf('offensive', 'avgTurnovers'),
      stl: valueOf('defensive', 'avgSteals'),
      blk: valueOf('defensive', 'avgBlocks'),
      pf: valueOf('general', 'avgFouls'),
    });

    athletes.push({
      id: a.id,
      name: a.displayName ?? '',
      teamId: a.teamId ?? '',
      headshot: a.headshot?.href ?? null,
      positionAbbr: a.position?.abbreviation ?? '',
    });
  }

  return {
    season: body.requestedSeason?.displayName ?? body.currentSeason?.displayName ?? '',
    leaders,
    athletes,
  };
}

/**
 * 팀별 시즌 평균. 팀당 한 번씩 30번 부른다.
 * 실점은 팀 스탯에 없고 순위 데이터에 있어 거기서 가져온다.
 */
async function fetchTeamStats(teams, pointsAgainstByTeam) {
  const rows = await mapLimit(teams, CONCURRENCY, async (team) => {
    try {
      const body = await getJson(`${SITE}/teams/${team.id}/statistics`);
      const stat = {};
      for (const category of body.results?.stats?.categories ?? []) {
        for (const s of category.stats ?? []) stat[s.name] = Number(s.value) || 0;
      }
      return {
        teamId: team.id,
        pointsFor: stat.avgPoints ?? 0,
        pointsAgainst: pointsAgainstByTeam.get(team.id) ?? 0,
        rebounds: stat.avgRebounds ?? 0,
        assists: stat.avgAssists ?? 0,
        steals: stat.avgSteals ?? 0,
        blocks: stat.avgBlocks ?? 0,
        fgm: stat.avgFieldGoalsMade ?? 0,
        fga: stat.avgFieldGoalsAttempted ?? 0,
        tpm: stat.avgThreePointFieldGoalsMade ?? 0,
        tpa: stat.avgThreePointFieldGoalsAttempted ?? 0,
        ftm: stat.avgFreeThrowsMade ?? 0,
        fta: stat.avgFreeThrowsAttempted ?? 0,
        oreb: stat.avgOffensiveRebounds ?? 0,
        dreb: stat.avgDefensiveRebounds ?? 0,
        tov: stat.avgTurnovers ?? 0,
        pf: stat.avgFouls ?? 0,
      };
    } catch (error) {
      console.warn(`  팀 스탯 실패 ${team.shortName}: ${error.message}`);
      return null;
    }
  });
  return rows.filter(Boolean);
}

/**
 * 선수별 드래프트·국적 정보. 벌크 엔드포인트에 없어 선수마다 부른다.
 *
 * 둘 다 거의 바뀌지 않으므로 지난 실행 결과를 먼저 쓰고, 거기 없는
 * 선수(새로 들어온 선수)만 새로 부른다. 같은 요청 한 번으로 둘 다 받는다.
 *
 * 국적은 citizenship과 출생 국가를 원본 그대로 따로 담는다. 해외에서
 * 태어나 다른 나라 국적인 선수가 있어 어느 쪽을 보여줄지는 앱이 정한다.
 */
async function fetchDrafts(playerIds) {
  const previous = await getPrevious('nba/players.json');
  const known = new Map();
  for (const p of previous?.players ?? []) {
    // 국적을 모으기 전 결과에는 birthCountry 키가 없다. 그런 선수는
    // 재사용하지 않고 다시 불러 국적까지 채운다.
    if ('draftYear' in p && 'birthCountry' in p) {
      known.set(p.id, {
        draftYear: p.draftYear,
        draftRound: p.draftRound,
        draftPick: p.draftPick,
        birthCountry: p.birthCountry,
        citizenship: p.citizenship ?? null,
      });
    }
  }

  const missing = playerIds.filter((id) => !known.has(id));
  console.log(`  드래프트·국적: 재사용 ${playerIds.length - missing.length}명, 새로 조회 ${missing.length}명`);

  let failures = 0;
  await mapLimit(missing, CONCURRENCY, async (id) => {
    try {
      const body = await getJson(`${ATHLETE}/${id}`);
      const d = body.draft;
      // 드래프트 기록이 없으면 미지명 선수다. 0이 아니라 null로 둔다.
      known.set(id, {
        draftYear: d?.year ?? null,
        draftRound: d?.round ?? null,
        draftPick: d?.selection ?? null,
        birthCountry: body.birthPlace?.country ?? null,
        citizenship: body.citizenship ?? null,
      });
    } catch (error) {
      // 실패한 선수는 기록하지 않아 다음 실행에서 다시 시도된다.
      failures += 1;
    }
  });
  if (failures > 0) console.warn(`  드래프트 조회 실패 ${failures}명 (다음 실행에서 재시도)`);
  return known;
}

/**
 * 끝난 경기의 박스스코어. 경기마다 한 번씩 부른다.
 *
 * 끝난 경기 기록은 바뀌지 않으므로 이미 올려둔 건 그대로 다시 쓴다.
 * 진행 중인 경기는 기록이 계속 바뀌어 매번 새로 받는다.
 */
async function fetchBoxScores(games) {
  const targets = games.filter((g) => g.status === 'finished' || g.status === 'live');
  let reused = 0;

  const results = await mapLimit(targets, CONCURRENCY, async (game) => {
    if (game.status === 'finished') {
      const previous = await getPrevious(`nba/boxscores/${game.id}.json`);
      if (previous?.lines?.length) {
        reused += 1;
        return previous;
      }
    }
    try {
      const body = await getJson(`${SITE}/summary?event=${game.id}`);
      const lines = [];
      for (const team of body.boxscore?.players ?? []) {
        const block = team.statistics?.[0];
        const keys = block?.keys ?? [];
        for (const row of block?.athletes ?? []) {
          // 출전하지 않은 선수는 기록 칸이 비어 온다.
          if (row.didNotPlay || !row.stats?.length) continue;
          const at = (key) => row.stats[keys.indexOf(key)];
          const [fgm, fga] = madeAttempted(at('fieldGoalsMade-fieldGoalsAttempted'));
          const [tpm, tpa] = madeAttempted(at('threePointFieldGoalsMade-threePointFieldGoalsAttempted'));
          const [ftm, fta] = madeAttempted(at('freeThrowsMade-freeThrowsAttempted'));
          lines.push({
            playerId: row.athlete?.id ?? '',
            name: row.athlete?.displayName ?? '',
            headshot: row.athlete?.headshot?.href ?? null,
            teamId: team.team?.id ?? '',
            minutes: Number(at('minutes')) || 0,
            points: Number(at('points')) || 0,
            fgm, fga, tpm, tpa, ftm, fta,
            oreb: Number(at('offensiveRebounds')) || 0,
            dreb: Number(at('defensiveRebounds')) || 0,
            ast: Number(at('assists')) || 0,
            tov: Number(at('turnovers')) || 0,
            stl: Number(at('steals')) || 0,
            blk: Number(at('blocks')) || 0,
            pf: Number(at('fouls')) || 0,
            // "+2", "-7"
            plusMinus: Number(at('plusMinus')) || 0,
          });
        }
      }
      return { gameId: game.id, lines };
    } catch (error) {
      console.warn(`  박스스코어 실패 ${game.id}: ${error.message}`);
      return null;
    }
  });

  console.log(`  박스스코어: 대상 ${targets.length}경기, 재사용 ${reused}`);
  return results.filter(Boolean);
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

  console.log('스탯 리더 수집...');
  const { season, leaders, athletes } = await fetchLeaders().catch((e) => {
    console.warn(`  리더 실패: ${e.message}`);
    return { season: '', leaders: [], athletes: [] };
  });
  console.log(`  ${leaders.length}명 (${season})`);

  console.log('팀 시즌 평균 수집...');
  const teamStats = await fetchTeamStats(
    teams,
    new Map(standings.map((s) => [s.teamId, s.pointsAgainst])),
  );
  console.log(`  ${teamStats.length}개 팀`);

  console.log('박스스코어 수집...');
  const boxScores = await fetchBoxScores(games);

  // 로스터에 없는 선수(자유계약, 시즌 중 이적)도 리더 목록과 박스스코어에는
  // 나온다. 선수 목록에 없으면 화면이 이름을 못 찾으므로 합쳐 둔다.
  const byId = new Map(players.map((p) => [p.id, p]));
  const addIfMissing = (id, name, teamId, headshot, abbr) => {
    if (!id || byId.has(id)) return;
    byId.set(id, {
      id,
      name,
      teamId,
      position: POSITION_BY_ABBR[abbr] ?? 'sf',
      positionLabel: POSITION_LABEL_BY_ABBR[abbr] ?? null,
      backNumber: 0,
      headshot,
      height: null,
      weight: null,
      college: null,
      birthDate: null,
      // 현재 로스터에는 없다는 표시. 팀 선수단 목록에서는 빠진다.
      offRoster: true,
    });
  };
  for (const a of athletes) addIfMissing(a.id, a.name, a.teamId, a.headshot, a.positionAbbr);
  for (const box of boxScores) {
    for (const line of box.lines) addIfMissing(line.playerId, line.name, line.teamId, line.headshot, '');
  }
  const allPlayers = [...byId.values()];
  console.log(`  선수 목록: 로스터 ${players.length} + 추가 ${allPlayers.length - players.length}`);

  console.log('드래프트 수집...');
  const drafts = await fetchDrafts(allPlayers.map((p) => p.id));
  for (const p of allPlayers) {
    const d = drafts.get(p.id);
    // 조회에 실패한 선수는 키를 아예 두지 않는다. 다음 실행에서 재시도된다.
    if (d) Object.assign(p, d);
  }

  await fs.mkdir(path.join(outDir, 'boxscores'), { recursive: true });
  const generatedAt = new Date().toISOString();
  const files = {
    teams,
    standings,
    games,
    players: allPlayers,
    leaders,
    team_stats: teamStats,
  };
  for (const [name, data] of Object.entries(files)) {
    const file = path.join(outDir, `${name}.json`);
    const payload = { generated_at: generatedAt, [name]: data };
    if (name === 'leaders') payload.season = season;
    await fs.writeFile(file, JSON.stringify(payload));
    console.log(`${file}: ${data.length}건`);
  }
  for (const box of boxScores) {
    await fs.writeFile(
      path.join(outDir, 'boxscores', `${box.gameId}.json`),
      JSON.stringify({ generated_at: generatedAt, ...box }),
    );
  }
  console.log(`boxscores/: ${boxScores.length}경기`);
}

// 직접 실행할 때만 수집한다. 테스트에서는 함수만 가져다 쓴다.
if (require.main === module) {
  main().catch((error) => {
    console.error('NBA 수집 실패:', error.message);
    process.exit(1);
  });
}

module.exports = { fetchBoxScores, fetchLeaders, madeAttempted, mapLimit };
