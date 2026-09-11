#!/usr/bin/env node
'use strict';

/**
 * KBL 공식 홈페이지(kbl.or.kr)가 쓰는 API에서 KBL 데이터를 모아 정적 JSON으로
 * 떨어뜨린다.
 *
 * 문서가 공개된 API는 아니다. 공식 홈페이지가 부르는 api.kbl.or.kr를 같은
 * 방식(Channel/TeamCode 헤더)으로 부른다. 결과 파일 모양은 NBA 수집기
 * (fetch-nba.js)와 같아서 앱은 같은 코드로 읽는다.
 *
 * 공식 사이트에 선수 신상(키·생년월일·출신교) API는 없어 담지 않는다.
 * 없는 값을 지어내지 않는다.
 *
 * 사용법: node tools/fetch-kbl.js <출력 디렉터리>
 */

const fs = require('fs/promises');
const path = require('path');

const API = 'https://api.kbl.or.kr';
const SITE = 'https://www.kbl.or.kr';

/** 지난 실행 결과. 끝난 경기 박스스코어와 지난 시즌 기록은 바뀌지 않아 다시 쓴다. */
const PREVIOUS_BASE = process.env.KBL_PREVIOUS_BASE_URL ?? '';

/** KBL 서버에 동시에 보낼 요청 수. NBA(ESPN)보다 작은 서버라 낮게 둔다. */
const CONCURRENCY = 4;

/** 일정을 오늘부터 며칠 뒤까지 받을지. 비시즌에도 개막 경기가 보이도록 넉넉히. */
const FUTURE_DAYS = 45;

/** 선수 시즌별 기록에 담을 정규시즌 수(최근 것부터). */
const HISTORY_SEASONS = 6;

/**
 * KBL 팀 코드 → 앱 팀.
 *
 * id는 앱이 처음부터 써 온 값이다. 사용자가 팔로우해 둔 팀과 뉴스 수집기의
 * 구단 매칭(news-source.js)이 이 id를 쓰므로 바꾸지 않는다. 색은 KBL
 * 홈페이지의 구단 색, 엠블럼은 홈페이지에 올라가 있는 공식 이미지다.
 */
const TEAMS = {
  55: { id: 'sk', city: '서울', name: 'SK', shortName: 'SK', color: '#AB0028', emblem: 'sk' },
  70: { id: 'kgc', city: '안양', name: '정관장', shortName: '정관장', color: '#CF1F25', emblem: 'kgc' },
  16: { id: 'db', city: '원주', name: 'DB', shortName: 'DB', color: '#03662C', emblem: 'db' },
  50: { id: 'lg', city: '창원', name: 'LG', shortName: 'LG', color: '#550E10', emblem: 'lg' },
  60: { id: 'kcc', city: '부산', name: 'KCC', shortName: 'KCC', color: '#07215A', emblem: 'kcc' },
  '06': { id: 'kt', city: '수원', name: 'KT', shortName: 'KT', color: '#E21820', emblem: 'kt' },
  64: { id: 'kogas', city: '대구', name: '한국가스공사', shortName: '한국가스공사', color: '#374EA2', emblem: 'pega' },
  66: { id: 'sono', city: '고양', name: '소노', shortName: '소노', color: '#72A3CD', emblem: null },
  10: { id: 'mobis', city: '울산', name: '현대모비스', shortName: '현대모비스', color: '#023370', emblem: 'hd' },
  35: { id: 'samsung', city: '서울', name: '삼성', shortName: '삼성', color: '#0C4DA1', emblem: 'ss' },
};

/** KBL 포지션 → [앱 enum 대표값, 화면 표기]. KBL은 가드/포워드/센터 세 가지로만 준다. */
const POSITIONS = {
  GD: ['pg', '가드'],
  FD: ['sf', '포워드'],
  C: ['c', '센터'],
};

const teamOf = (code) => TEAMS[String(code ?? '')] ?? null;

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

async function kblGet(pathname, params = {}) {
  const query = new URLSearchParams(
    Object.entries(params).filter(([, v]) => v != null),
  ).toString();
  const url = `${API}${pathname}${query ? `?${query}` : ''}`;
  // 헤더가 없으면 서버가 500을 준다. 홈페이지(kbl.or.kr)가 보내는 값 그대로다.
  const res = await fetch(url, {
    headers: { Channel: 'WEB', TeamCode: 'XX', lang: 'ko', 'X-Requested-With': 'XMLHttpRequest' },
    signal: AbortSignal.timeout(20000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
  const body = await res.json();
  if (body && !Array.isArray(body) && body.resultCode === 'Fail') {
    throw new Error(`${body.message} ${url}`);
  }
  return body;
}

/** 지난 실행 결과를 읽는다. 없거나 실패하면 null. */
async function getPrevious(relativePath) {
  if (!PREVIOUS_BASE) return null;
  try {
    const res = await fetch(`${PREVIOUS_BASE}/${relativePath}`, { signal: AbortSignal.timeout(15000) });
    if (!res.ok) return null;
    return await res.json();
  } catch (_) {
    return null;
  }
}

/** 한국 날짜 "YYYYMMDD". [offsetDays]만큼 옮긴다. */
function kstDate(offsetDays = 0, now = new Date()) {
  const d = new Date(now.getTime() + 9 * 3600 * 1000 + offsetDays * 86400 * 1000);
  return (
    String(d.getUTCFullYear()) +
    String(d.getUTCMonth() + 1).padStart(2, '0') +
    String(d.getUTCDate()).padStart(2, '0')
  );
}

/** "2025-2026" → "2025-26". NBA 데이터와 같은 표기로 맞춘다. */
function seasonLabel(seasonName) {
  const m = String(seasonName ?? '').match(/^(\d{4})-(\d{4})$/);
  return m ? `${m[1]}-${m[2].slice(2)}` : String(seasonName ?? '');
}

/** 이미 시작한 정규시즌을 최신순으로. 첫 번째가 지금(또는 막 끝난) 시즌이다. */
function startedSeasons(seasons, today) {
  return seasons
    .filter((s) => s.seasonCategory === 'R' && String(s.gamedateStart) <= today)
    .sort((a, b) => String(b.gamedateStart).localeCompare(String(a.gamedateStart)));
}

/** "KANG SANG JAE" → "Kang Sang Jae". 한글이 섞였거나 비었으면 null. */
function englishName(ename) {
  const s = String(ename ?? '').trim();
  if (!s || /[가-힣]/.test(s)) return null;
  if (s !== s.toUpperCase()) return s; // 외국인 선수는 이미 "Jameel Warney"
  return s.toLowerCase().replace(/\b([a-z])/g, (c) => c.toUpperCase());
}

function toTeam(code) {
  const t = teamOf(code);
  return {
    id: t.id,
    city: t.city,
    name: t.name,
    shortName: t.shortName,
    color: t.color,
    // 소노는 홈페이지에 PNG 엠블럼이 없고 SVG 아이콘만 있다. 웹은 SVG를 그리고,
    // 못 그리는 모바일은 팀 이름 글자로 대신한다.
    logo: t.emblem
      ? `${SITE}/assets/img/club/${t.emblem}/emblem-${t.emblem}01.png`
      : `${SITE}/assets/img/ico/logo/ic-${t.id}.svg`,
  };
}

/** KBL 선수(목록·기록·박스스코어의 player 객체) → 앱 선수. */
function toPlayer(p) {
  const [position, positionLabel] = POSITIONS[p.pos] ?? ['sf', null];
  return {
    id: String(p.pcode),
    name: p.pname ?? '',
    nameEn: englishName(p.ename),
    teamId: teamOf(p.tcode)?.id ?? '',
    position,
    positionLabel,
    backNumber: Number(p.backNum) || 0,
    headshot: p.img ?? `https://kbl.or.kr/files/kbl/players-photo/${p.pcode}.png`,
  };
}

function quarterLabel(q) {
  const s = String(q ?? '');
  if (/^[1-4]$/.test(s)) return `${s}쿼터`;
  if (/^(OT|E)\d*$/i.test(s)) return '연장';
  return null;
}

/** 일정 한 건 → 앱 경기. KBL 10개 구단끼리가 아닌 경기(국제 대회 등)는 null. */
function toGame(m) {
  const home = teamOf(m.tcodeH);
  const away = teamOf(m.tcodeA);
  if (!home || !away || !m.gmkey || !m.gameDate) return null;
  const status = m.isEnded === 1 ? 'finished' : m.isStarted === 1 ? 'live' : 'scheduled';
  const d = String(m.gameDate);
  const t = String(m.gameStart ?? '0000').padStart(4, '0');
  return {
    id: m.gmkey,
    // 경기 시각은 한국 시간으로 온다. 앱이 기기 시간대로 바꿔 보여준다.
    startTime: `${d.slice(0, 4)}-${d.slice(4, 6)}-${d.slice(6, 8)}T${t.slice(0, 2)}:${t.slice(2, 4)}:00+09:00`,
    homeTeamId: home.id,
    awayTeamId: away.id,
    homeScore: Number(m.scoreH) || 0,
    awayScore: Number(m.scoreA) || 0,
    status,
    liveClock: status === 'live' ? quarterLabel(m.playingQuarter) : null,
    // 실점·더블더블 집계를 정규시즌 경기로만 하기 위해 남긴다.
    glkey: m.glkey ?? null,
  };
}

/** 누적 초. KBL은 분(playMin)과 남은 초(playSec)를 나눠 준다. */
const secondsOf = (r) => (Number(r.playMin) || 0) * 60 + (Number(r.playSec) || 0);

/** 박스스코어 한 줄. 뛰지 않은 선수(출전 시간 0)는 null. */
function toBoxLine(row) {
  const r = row.records ?? {};
  const p = row.player ?? {};
  const seconds = secondsOf(r);
  if (seconds === 0) return null;
  const n = (v) => Number(v) || 0;
  return {
    playerId: String(p.pcode),
    name: p.pname ?? '',
    headshot: p.img ?? null,
    teamId: teamOf(p.tcode)?.id ?? '',
    minutes: Math.round(seconds / 60),
    points: n(r.score),
    // fg/fgA는 2점슛만, fgt/fgtA가 3점을 포함한 전체 야투다.
    fgm: n(r.fgt),
    fga: n(r.fgtA),
    tpm: n(r.threep),
    tpa: n(r.threepA),
    ftm: n(r.ft),
    fta: n(r.ftA),
    oreb: n(r.offr),
    dreb: n(r.defr),
    ast: n(r.ast),
    tov: n(r.to),
    stl: n(r.stl),
    blk: n(r.bs),
    pf: n(r.foul),
    plusMinus: n(r.marginCn),
  };
}

/** 한 경기 기록에서 두 자릿수를 찍은 부문 수(득점·리바운드·어시스트·스틸·블록). */
function doubleDigitCount(line) {
  return [line.points, line.oreb + line.dreb, line.ast, line.stl, line.blk].filter((v) => v >= 10).length;
}

/** 시즌 누적 기록 한 줄 → 경기당 평균. 리더(랭킹)와 선수 시즌별 기록에 쓴다. */
function toSeasonAverages(row) {
  const r = row.records ?? {};
  const gp = Number(row.gameCount) || 0;
  const per = (v) => (gp ? (Number(v) || 0) / gp : 0);
  return {
    playerId: String(row.player?.pcode ?? ''),
    teamId: teamOf(row.player?.tcode)?.id ?? String(row.player?.tcode ?? ''),
    gamesPlayed: gp,
    minutes: gp ? secondsOf(r) / 60 / gp : 0,
    points: per(r.score),
    fgm: per(r.fgt),
    fga: per(r.fgtA),
    tpm: per(r.threep),
    tpa: per(r.threepA),
    ftm: per(r.ft),
    fta: per(r.ftA),
    oreb: per(r.offr),
    dreb: per(r.defr),
    reb: per(r.rb),
    ast: per(r.ast),
    tov: per(r.to),
    stl: per(r.stl),
    blk: per(r.bs),
    pf: per(r.foul),
  };
}

/** 팀 순위 한 줄(시즌 누적) → 팀 시즌 평균. */
function toTeamStats(row, pointsAgainst) {
  const gc = Number(row.gameCount) || 0;
  const n = (v) => Number(v) || 0;
  const per = (v) => (gc ? v / gc : 0);
  return {
    teamId: teamOf(row.teamCode).id,
    pointsFor: per(n(row.score)),
    pointsAgainst,
    rebounds: per(n(row.OR) + n(row.DR)),
    assists: per(n(row.AS)),
    steals: per(n(row.ST)),
    blocks: per(n(row.BS)),
    // 순위 데이터의 fg도 2점슛만이다. 3점을 더해 전체 야투로 맞춘다.
    fgm: per(n(row.fg) + n(row.threep)),
    fga: per(n(row.fgA) + n(row.threepA)),
    tpm: per(n(row.threep)),
    tpa: per(n(row.threepA)),
    ftm: per(n(row.ft)),
    fta: per(n(row.ftA)),
    oreb: per(n(row.OR)),
    dreb: per(n(row.DR)),
    tov: per(n(row.TO)),
    pf: per(n(row.foulTot)),
  };
}

/** 끝난 경기 결과로 팀별 경기당 실점. 순위 데이터에 실점이 없어 직접 계산한다. */
function pointsAgainstByTeam(games) {
  const sums = new Map();
  for (const g of games) {
    if (g.status !== 'finished') continue;
    for (const [teamId, allowed] of [[g.homeTeamId, g.awayScore], [g.awayTeamId, g.homeScore]]) {
      const s = sums.get(teamId) ?? { total: 0, count: 0 };
      s.total += allowed;
      s.count += 1;
      sums.set(teamId, s);
    }
  }
  return new Map([...sums].map(([id, s]) => [id, s.total / s.count]));
}

/**
 * 박스스코어로 선수별 더블더블·트리플더블 횟수와 한 경기 최다 득점을 센다.
 * 시즌 기록 API에는 이 값이 없다.
 */
function seasonHighlights(boxScores) {
  const byPlayer = new Map();
  for (const box of boxScores) {
    for (const line of box.lines) {
      const s = byPlayer.get(line.playerId) ?? { dd2: 0, td3: 0, gameHigh: 0 };
      const count = doubleDigitCount(line);
      if (count >= 2) s.dd2 += 1;
      if (count >= 3) s.td3 += 1;
      s.gameHigh = Math.max(s.gameHigh, line.points);
      byPlayer.set(line.playerId, s);
    }
  }
  return byPlayer;
}

/** [fromDate]부터 [toDate]까지 일정. 한 달씩 끊어 부른다. */
async function fetchGames(fromDate, toDate) {
  const games = [];
  const seen = new Set();
  const parse = (ymd) => new Date(Date.UTC(+ymd.slice(0, 4), +ymd.slice(4, 6) - 1, +ymd.slice(6, 8)));
  const fmt = (d) => d.toISOString().slice(0, 10).replace(/-/g, '');
  for (let start = parse(fromDate); start <= parse(toDate); ) {
    const end = new Date(Math.min(start.getTime() + 30 * 86400 * 1000, parse(toDate).getTime()));
    try {
      const list = await kblGet('/match/list', { fromDate: fmt(start), toDate: fmt(end), tcodeList: 'all' });
      for (const m of Array.isArray(list) ? list : []) {
        const game = toGame(m);
        if (game && !seen.has(game.id)) {
          seen.add(game.id);
          games.push(game);
        }
      }
    } catch (error) {
      console.warn(`  일정 실패 ${fmt(start)}-${fmt(end)}: ${error.message}`);
    }
    start = new Date(end.getTime() + 86400 * 1000);
  }
  return games.sort((a, b) => a.startTime.localeCompare(b.startTime));
}

/** 끝났거나 진행 중인 경기의 박스스코어. 끝난 경기는 지난 결과를 다시 쓴다. */
async function fetchBoxScores(games) {
  const targets = games.filter((g) => g.status === 'finished' || g.status === 'live');
  let reused = 0;
  let failed = 0;
  const results = await mapLimit(targets, CONCURRENCY, async (game) => {
    if (game.status === 'finished') {
      const previous = await getPrevious(`kbl/boxscores/${game.id}.json`);
      if (previous?.lines?.length) {
        reused += 1;
        return previous;
      }
    }
    try {
      const rows = await kblGet(`/match/${game.id}/player-stat`);
      const lines = (Array.isArray(rows) ? rows : []).map(toBoxLine).filter(Boolean);
      if (lines.length === 0) throw new Error('기록 없음');
      return { gameId: game.id, lines };
    } catch (error) {
      failed += 1;
      return null;
    }
  });
  console.log(`  박스스코어: 대상 ${targets.length}경기, 재사용 ${reused}, 실패 ${failed}`);
  return results.filter(Boolean);
}

/**
 * 최근 정규시즌들의 선수별 시즌 평균. 선수 상세의 시즌별 기록에 쓴다.
 * 끝난 시즌은 바뀌지 않아 지난 결과를 쓰고, 지금 시즌만 새로 부른다.
 */
async function fetchPlayerSeasons(seasons, currentGlkey) {
  const previous = await getPrevious('kbl/player_seasons.json');
  const rows = [];
  for (const season of seasons) {
    const label = seasonLabel(season.seasonName);
    const old = (previous?.rows ?? []).filter((r) => r.season === label);
    if (season.glkey !== currentGlkey && old.length > 0) {
      rows.push(...old);
      continue;
    }
    try {
      const list = await kblGet(`/leagues/${season.glkey}/stats/players`);
      for (const row of Array.isArray(list) ? list : []) {
        if (!(Number(row.gameCount) > 0)) continue;
        rows.push({ ...toSeasonAverages(row), season: label, teamName: row.player?.tname ?? null });
      }
    } catch (error) {
      console.warn(`  ${label} 시즌 기록 실패: ${error.message}`);
      rows.push(...old);
    }
  }
  return rows;
}

async function main() {
  const outDir = process.argv[2];
  if (!outDir) {
    console.error('사용법: node tools/fetch-kbl.js <출력 디렉터리>');
    process.exit(1);
  }
  const today = kstDate();

  console.log('KBL 시즌 확인...');
  const seasonList = await kblGet('/season/list', { seasonCategory: 'R', gameCode: '01', seasonGrade: 1 });
  const seasons = startedSeasons(seasonList, today);
  const current = seasons[0];
  if (!current) {
    console.error('시작한 정규시즌이 없습니다. 기존 데이터를 지우지 않기 위해 중단합니다.');
    process.exit(1);
  }
  const season = seasonLabel(current.seasonName);
  console.log(`  기준 시즌 ${season} (${current.glkey})`);

  console.log('팀 확인...');
  const teamList = await kblGet('/common/teamList', { kblYn: 'Y', sangumuYn: 'Y' });
  // XX는 리그 전체, 75는 상무(국군체육부대)로 D리그에만 나와 정규리그 팀이 아니다.
  const notLeagueTeams = new Set(['XX', '75']);
  const unknownTeams = (teamList ?? []).filter(
    (t) => !notLeagueTeams.has(t.teamCode) && !teamOf(t.teamCode),
  );
  if (unknownTeams.length > 0) {
    // 구단 이름이 바뀌거나 새 구단이 생긴 경우. TEAMS에 추가해야 한다.
    console.warn(`  모르는 팀 코드: ${unknownTeams.map((t) => `${t.teamCode}=${t.teamNameFull}`).join(', ')}`);
  }
  const teams = Object.keys(TEAMS).map(toTeam);

  console.log('선수 명단 수집...');
  const roster = (await kblGet('/players', { searchOption: 'active' })).map(toPlayer);
  console.log(`  ${roster.length}명`);
  if (roster.length === 0) {
    console.error('선수 명단이 비었습니다. 기존 데이터를 지우지 않기 위해 중단합니다.');
    process.exit(1);
  }

  console.log('순위 수집...');
  const rank = await kblGet(`/league/rank/${current.glkey}`).catch((e) => {
    console.warn(`  순위 실패: ${e.message}`);
    return [];
  });

  console.log('일정 수집...');
  // 전체 일정: 다음 시즌 일정이 발표돼 있으면 그 시즌 마지막 날까지 받는다.
  const lastSeasonDay = seasonList
    .filter((s) => s.seasonCategory === 'R' && /^\d{8}$/.test(String(s.gamedateEnd ?? '')))
    .map((s) => String(s.gamedateEnd))
    .sort()
    .pop();
  const scheduleEnd = [kstDate(FUTURE_DAYS), lastSeasonDay ?? ''].sort().pop();
  const games = await fetchGames(String(current.gamedateStart), scheduleEnd);
  console.log(`  ${games.length}경기`);

  console.log('박스스코어 수집...');
  const boxScores = await fetchBoxScores(games);

  const seasonGames = games.filter((g) => g.glkey === current.glkey);
  const againstByTeam = pointsAgainstByTeam(seasonGames);

  const standings = [...rank]
    .filter((r) => teamOf(r.teamCode))
    .sort((a, b) => a.rank - b.rank)
    .map((r) => ({
      teamId: teamOf(r.teamCode).id,
      wins: Number(r.TWin) || 0,
      losses: Number(r.TLoss) || 0,
      gamesBehind: Number(r.winDiff) || 0,
      pointsAgainst: againstByTeam.get(teamOf(r.teamCode).id) ?? 0,
      conference: '',
    }));
  const teamStats = rank
    .filter((r) => teamOf(r.teamCode))
    .map((r) => toTeamStats(r, againstByTeam.get(teamOf(r.teamCode).id) ?? 0));

  console.log('시즌 기록 수집...');
  const statRows = await kblGet(`/leagues/${current.glkey}/stats/players`).catch((e) => {
    console.warn(`  시즌 기록 실패: ${e.message}`);
    return [];
  });
  const leaders = statRows.filter((r) => Number(r.gameCount) > 0).map(toSeasonAverages);

  // 더블더블·최다 득점은 이번 시즌 끝난 경기 박스스코어가 전부 있을 때만 넣는다.
  // 몇 경기라도 빠지면 횟수가 실제보다 적게 나와 순위가 틀린다.
  const finishedThisSeason = seasonGames.filter((g) => g.status === 'finished');
  const seasonBoxes = boxScores.filter((b) => finishedThisSeason.some((g) => g.id === b.gameId));
  const complete = finishedThisSeason.length > 0 && seasonBoxes.length === finishedThisSeason.length;
  if (complete) {
    const highlights = seasonHighlights(seasonBoxes);
    for (const row of leaders) {
      const h = highlights.get(row.playerId) ?? { dd2: 0, td3: 0, gameHigh: 0 };
      Object.assign(row, h);
    }
  }
  console.log(
    `  ${leaders.length}명 · 박스스코어 ${seasonBoxes.length}/${finishedThisSeason.length}경기` +
      (complete ? '' : ' (모자라 더블더블·최다 득점은 뺌)'),
  );

  console.log('선수 시즌별 기록 수집...');
  const playerSeasons = await fetchPlayerSeasons(seasons.slice(0, HISTORY_SEASONS), current.glkey);
  console.log(`  ${playerSeasons.length}줄`);

  // 은퇴·방출된 선수도 기록과 박스스코어에는 나온다. 이름을 찾을 수 있게 합친다.
  const byId = new Map(roster.map((p) => [p.id, p]));
  const addIfMissing = (player) => {
    if (!player?.pcode || byId.has(String(player.pcode))) return;
    byId.set(String(player.pcode), { ...toPlayer(player), offRoster: true });
  };
  for (const row of statRows) addIfMissing(row.player);
  const lineOwners = new Map();
  for (const box of boxScores) {
    for (const line of box.lines) {
      lineOwners.set(line.playerId, { pcode: line.playerId, pname: line.name, img: line.headshot });
    }
  }
  for (const owner of lineOwners.values()) addIfMissing(owner);
  const players = [...byId.values()];

  await fs.mkdir(path.join(outDir, 'boxscores'), { recursive: true });
  const generatedAt = new Date().toISOString();
  const files = {
    teams,
    standings,
    games: games.map(({ glkey, ...game }) => game),
    players,
    leaders,
    team_stats: teamStats,
  };
  for (const [name, data] of Object.entries(files)) {
    const payload = { generated_at: generatedAt, [name]: data };
    if (name === 'leaders') payload.season = season;
    await fs.writeFile(path.join(outDir, `${name}.json`), JSON.stringify(payload));
    console.log(`${name}.json: ${data.length}건`);
  }
  await fs.writeFile(
    path.join(outDir, 'player_seasons.json'),
    JSON.stringify({ generated_at: generatedAt, rows: playerSeasons }),
  );
  for (const box of boxScores) {
    await fs.writeFile(
      path.join(outDir, 'boxscores', `${box.gameId}.json`),
      JSON.stringify({ generated_at: generatedAt, gameId: box.gameId, lines: box.lines }),
    );
  }
  console.log(`player_seasons.json: ${playerSeasons.length}줄, boxscores/: ${boxScores.length}경기`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error('KBL 수집 실패:', error.message);
    process.exit(1);
  });
}

module.exports = {
  TEAMS,
  doubleDigitCount,
  englishName,
  kstDate,
  pointsAgainstByTeam,
  seasonHighlights,
  seasonLabel,
  startedSeasons,
  toBoxLine,
  toGame,
  toPlayer,
  toSeasonAverages,
  toTeam,
  toTeamStats,
};
