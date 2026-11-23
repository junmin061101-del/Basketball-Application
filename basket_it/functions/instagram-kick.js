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
  const keys = pendingNights({ kblDay, kblGames, nbaDay: nba, nbaEvents: scoreboard.events ?? [], posted });
  if (!keys.length) return keys;
  const res = await fetchImpl(`https://api.github.com/repos/${REPO}/actions/workflows/news.yml/dispatches`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/vnd.github+json' },
    body: JSON.stringify({ ref: 'main' }),
  });
  if (!res.ok) throw new Error(`수집기 깨우기 실패 HTTP ${res.status}`);
  return keys;
}

module.exports = { kickInstagram, pendingNights, nbaDay };
