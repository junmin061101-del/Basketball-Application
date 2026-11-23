'use strict';

/**
 * 그날 마지막 경기가 끝났는데 인스타에 아직 안 올렸으면 수집기(news.yml)를 깨운다.
 *
 * 수집기가 끝나면 instagram-post.yml이 카드를 그려 올린다. GitHub 예약 실행은 몇
 * 시간씩 밀려서, 경기 끝은 여기(20분마다)서 본다. 올렸는지는 instagram 브랜치의
 * posted.json으로 안다. 그 기록을 못 읽어 한 번 더 깨워도 게시 쪽이 다시 확인하므로
 * 두 번 올라가지 않는다. 여기는 "지금 깨울까"만 정한다.
 *
 * - KBL: KBL 일정 API(오늘, 한국 날짜)
 * - NBA: ESPN 스코어보드(미국 경기일). 카드 데이터가 아니라 "끝났나" 신호로만 쓴다.
 */

const { fetchGames, kstDate } = require('./live-score');

const REPO = 'junmin061101-del/Basketball-Application';
const ESPN = 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard';

/**
 * 경기 일정 게시: 앞으로 경기가 있는 한국 날짜마다, 그날 첫 경기 12시간 전에 올린다.
 * 그 시각이 새벽(9시 전)이면 그날 아침 9시로 미룬다. 지금 올릴 날짜(아직 안 올렸고,
 * 그날 첫 경기 전이고, 올릴 시각이 지났다)를 돌려준다. 없으면 null.
 * games: 정적 JSON의 경기들(startTime ISO). tools/instagram/post.js도 이걸 쓴다.
 */
function dueSchedule(league, games, posted, nowMs) {
  const kst = (ms) => new Date(ms + 9 * 3600e3).toISOString().slice(0, 10);
  const firstByDay = {};
  for (const g of games) {
    if (!g.startTime) continue;
    const t = Date.parse(g.startTime);
    const d = kst(t);
    firstByDay[d] = Math.min(firstByDay[d] ?? Infinity, t);
  }
  for (const [day, first] of Object.entries(firstByDay).sort()) {
    if (first <= nowMs || posted[`${league}-schedule-${day}`]) continue;
    let at = first - 12 * 3600e3;
    if (new Date(at + 9 * 3600e3).getUTCHours() < 9) at = Date.parse(`${kst(at)}T09:00:00+09:00`);
    if (nowMs >= at) return day;
  }
  return null;
}

/** 미국 경기일. 동부 시각 오전 6시(UTC 11시, 한국 저녁 8시)에 넘어간다. */
const nbaDay = (nowMs) => new Date(nowMs - 11 * 3600e3).toISOString().slice(0, 10);

/** 경기가 다 끝났는데 아직 안 올린 밤들("kbl-2026-11-22"). */
function pendingNights({ kblDay, kblGames, nbaDay: nba, nbaEvents, posted }) {
  const keys = [];
  if (kblGames.length && kblGames.every((g) => g.status === 'final')) keys.push(`kbl-${kblDay}`);
  if (nbaEvents.length && nbaEvents.every((e) => e.status?.type?.state === 'post')) keys.push(`nba-${nba}`);
  return keys.filter((k) => !posted[k]);
}

async function kickInstagram({ token, fetchImpl = fetch, nowMs = Date.now() }) {
  const json = (url, fallback) =>
    fetchImpl(url, { signal: AbortSignal.timeout(15000) })
      .then((r) => (r.ok ? r.json() : fallback))
      .catch(() => fallback);
  const kblDay = kstDate(nowMs).replace(/(\d{4})(\d{2})(\d{2})/, '$1-$2-$3');
  const nba = nbaDay(nowMs);
  const [kblGames, scoreboard, posted] = await Promise.all([
    fetchGames(fetchImpl, nowMs),
    json(`${ESPN}?dates=${nba.replace(/-/g, '')}`, { events: [] }),
    json(`https://raw.githubusercontent.com/${REPO}/instagram/posted.json?t=${nowMs}`, {}),
  ]);
  const dispatch = async (workflow) => {
    const res = await fetchImpl(`https://api.github.com/repos/${REPO}/actions/workflows/${workflow}/dispatches`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json' },
      body: JSON.stringify({ ref: 'main' }),
    });
    if (!res.ok) throw new Error(`${workflow} 깨우기 실패 HTTP ${res.status}`);
  };
  const keys = pendingNights({ kblDay, kblGames, nbaDay: nba, nbaEvents: scoreboard.events ?? [], posted });
  if (keys.length) {
    await dispatch('news.yml'); // 수집이 끝나면 게시가 이어서 돈다(일정도 함께 본다)
    return keys;
  }
  // 다음 날 경기 일정: 데이터는 이미 올라가 있으니 게시만 깨운다.
  const pages = 'https://junmin061101-del.github.io/Basketball-Application';
  const schedules = [];
  for (const league of ['kbl', 'nba']) {
    const { games = [] } = await json(`${pages}/${league}/games.json?t=${nowMs}`, {});
    const day = dueSchedule(league, games, posted, nowMs);
    if (day) schedules.push(`${league}-schedule-${day}`);
  }
  if (schedules.length) await dispatch('instagram-post.yml');
  return schedules;
}

module.exports = { kickInstagram, pendingNights, nbaDay, dueSchedule };
