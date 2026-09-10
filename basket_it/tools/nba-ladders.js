'use strict';

/**
 * NBA.com 수상 레이스(사다리)와 시즌 수상 결과를 모은다.
 *
 * NBA.com 기자들이 시즌 중 주마다 올리는 Kia MVP Ladder / Kia Rookie Ladder
 * 기사가 원본이다. 공식 API가 없어 기사 페이지에 박힌 __NEXT_DATA__ JSON의
 * 본문 HTML에서 "1. 이름, 팀" 줄을 뽑는다. 순위는 기자 한 명의 판단이지
 * 투표 결과가 아니므로 앱에서도 그렇게 표시한다.
 *
 * DPOY 사다리는 NBA.com이 2023년 이후 발행하지 않는다. 카테고리는 계속
 * 확인하되, 이번·지난 시즌 기사가 없으면 비워 둔다. 대신 시즌 수상 결과
 * (수상자·최종 후보)는 공식 발표 기사에서 가져온다.
 *
 * 사다리는 일주일에 한 번 바뀌므로 매 수집(20분)마다 가져오지 않고 몇 시간에
 * 한 번만 확인한다.
 */

const NBA = 'https://www.nba.com';

/** 사다리를 다시 확인하는 간격. */
const RECHECK_MS = 3 * 60 * 60 * 1000;

const AWARDS = [
  {
    key: 'mvp',
    category: 'kia-race-to-the-mvp-ladder',
    // 같은 카테고리에 파이널 MVP 사다리, 주간 요약(updates)도 섞여 있다.
    slug: /^kia-mvp-ladder-(?!updates)/,
    resultTitle: /Most Valuable Player/i,
  },
  {
    key: 'dpoy',
    category: 'defensive-player-ladder',
    slug: /defensive-player-ladder|dpoy-ladder/,
    resultTitle: /Defensive Player of the Year/i,
  },
  {
    key: 'roy',
    category: 'kia-rookie-ladder',
    slug: /^kia-rookie-ladder-/,
    resultTitle: /Rookie of the Year/i,
  },
];

/** 발행일 → "2025-26". NBA 시즌은 가을에 시작하므로 8월부터 새 시즌으로 본다. */
function seasonOf(isoDate) {
  const d = new Date(isoDate);
  const y = d.getUTCFullYear();
  const start = d.getUTCMonth() >= 7 ? y : y - 1;
  return `${start}-${String((start + 1) % 100).padStart(2, '0')}`;
}

/** "2025-26" → "2024-25". */
function previousSeason(season) {
  const start = Number(String(season).slice(0, 4));
  if (!start) return null;
  return `${start - 1}-${String(start % 100).padStart(2, '0')}`;
}

/** 시즌 수상 결과 기사 주소. "2025-26" → .../2025-2026-regular-season-awards */
function awardsUrl(season) {
  const start = Number(String(season).slice(0, 4));
  return `${NBA}/news/${start}-${start + 1}-regular-season-awards`;
}

const ENTITIES = {
  amp: '&',
  lt: '<',
  gt: '>',
  quot: '"',
  apos: "'",
  nbsp: ' ',
  rsquo: '’',
  lsquo: '‘',
  ldquo: '“',
  rdquo: '”',
  mdash: '—',
  ndash: '–',
  hellip: '…',
};

function decodeEntities(text) {
  return text.replace(/&(#x?[0-9a-f]+|[a-z]+);/gi, (match, code) => {
    if (code[0] === '#') {
      const n = code[1] === 'x' || code[1] === 'X'
        ? parseInt(code.slice(2), 16)
        : parseInt(code.slice(1), 10);
      return Number.isFinite(n) ? String.fromCodePoint(n) : match;
    }
    return ENTITIES[code.toLowerCase()] ?? match;
  });
}

/**
 * 기사 본문 HTML → 텍스트 줄. 블록 태그와 <br>에서 줄을 나눈다.
 * 번호 목록(<ol>)은 브라우저처럼 "1. "을 붙인다(신인 사다리 최종판이 이 형식).
 */
function htmlToLines(html) {
  let s = String(html ?? '');
  s = s.replace(/<ol[^>]*>([\s\S]*?)<\/ol>/gi, (_, inner) => {
    let n = 0;
    return inner.replace(/<li[^>]*>/gi, () => `\n${++n}. `);
  });
  s = s
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|h[1-6]|li|div|ul|ol|blockquote)>/gi, '\n')
    .replace(/<(p|h[1-6]|li|div|hr|ul|blockquote)(\s[^>]*)?\/?>/gi, '\n')
    .replace(/<[^>]+>/g, '');
  return decodeEntities(s)
    .split('\n')
    .map((line) => line.replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

/** "Nikola Jokić" / "NIkola Jokic" / "Jimmy Butler III" → 비교용 키. */
function normalizeName(name) {
  return String(name ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\b(jr|sr|ii|iii|iv)\b\.?/g, '')
    .replace(/[^a-z]/g, '');
}

const TEAM_ALIASES = {
  laclippers: 'losangelesclippers',
  losangelesclippers: 'laclippers',
  lalakers: 'losangeleslakers',
  losangeleslakers: 'lalakers',
};

/** 영문 팀 이름 → ESPN 팀 id를 찾는 함수. [teams]는 번역 전 ESPN 팀. */
function teamMatcher(teams) {
  const byKey = new Map();
  for (const t of teams) {
    const full = `${t.cityEn ?? t.city} ${t.nameEn ?? t.name}`;
    const key = full.toLowerCase().replace(/[^a-z0-9]/g, '');
    byKey.set(key, t.id);
    if (TEAM_ALIASES[key]) byKey.set(TEAM_ALIASES[key], t.id);
  }
  return (name) => byKey.get(String(name ?? '').toLowerCase().replace(/[^a-z0-9]/g, '')) ?? null;
}

/**
 * 기사 속 선수 이름 → ESPN 선수 id를 찾는 함수.
 * 비시즌에는 이적이 많아 팀은 동명이인을 가를 때만 쓴다.
 */
function playerMatcher(players) {
  const byName = new Map();
  for (const p of players) {
    const key = normalizeName(p.nameEn ?? p.name);
    if (!key) continue;
    if (!byName.has(key)) byName.set(key, []);
    byName.get(key).push(p);
  }
  return (name, teamId) => {
    const candidates = byName.get(normalizeName(name)) ?? [];
    if (candidates.length === 0) return null;
    if (candidates.length === 1) return candidates[0].id;
    return (candidates.find((p) => p.teamId === teamId) ?? candidates[0]).id;
  };
}

const MOVEMENT = { '⬆': 'up', '⬇': 'down', '↔': 'same' };

function movementOf(text) {
  const arrow = String(text ?? '').match(/[⬆⬇↔]/u);
  return arrow ? MOVEMENT[arrow[0]] : null;
}

/** "1. Shai Gilgeous-Alexander, Oklahoma City Thunder ⬆️" */
const ENTRY_LINE = /^(\d{1,2})\.\s*(.+?),\s*(.+?)\s*([⬆⬇↔]️?)?\s*$/u;

/** "Last week's ranking: No. 2 ⬆️" / "Last Ladder: No. 5" / "Last week's ranking: Not ranked" */
const PREVIOUS_LINE = /(?:Last week['’]?s ranking|Last Ladder|Previous ranking|Last week)\s*:\s*(?:No\.\s*(\d+)|(Not ranked|Unranked|NR))/i;

/**
 * 사다리 기사 본문에서 순위를 뽑는다.
 *
 * 1~5위는 "<h3>1. 이름, 팀</h3>" 뒤에 지난주 순위가, 6~10위는 "The next 5"
 * 아래에 한 줄씩(화살표만) 온다. 팀 이름이 실제 NBA 팀일 때만 순위 줄로
 * 인정해 본문 속 번호 매긴 문장이 섞이지 않게 한다.
 */
function parseLadder(html, teamIdOf) {
  const entries = [];
  let current = null;
  for (const line of htmlToLines(html)) {
    const m = line.match(ENTRY_LINE);
    const teamId = m ? teamIdOf(m[3]) : null;
    if (m && teamId) {
      const rank = Number(m[1]);
      if (entries.some((e) => e.rank === rank)) {
        current = null;
        continue;
      }
      current = {
        rank,
        nameEn: m[2].trim(),
        teamId,
        previousRank: null,
        movement: movementOf(m[4]),
      };
      entries.push(current);
      continue;
    }
    if (!current) continue;
    const prev = line.match(PREVIOUS_LINE);
    if (prev) {
      if (prev[1]) {
        current.previousRank = Number(prev[1]);
        current.movement =
          current.previousRank > current.rank ? 'up'
            : current.previousRank < current.rank ? 'down'
              : 'same';
      } else {
        current.movement = 'new';
      }
    }
  }
  return entries.sort((a, b) => a.rank - b.rank);
}

/**
 * 시즌 수상 발표 기사에서 상별 수상자·최종 후보를 뽑는다.
 * "<h2>Kia NBA Most Valuable Player</h2>" 아래 "Winner: 이름, 팀"과 후보 목록.
 */
function parseAwardResults(html, teamIdOf) {
  const results = {};
  for (const section of String(html ?? '').split(/<h2[^>]*>/i).slice(1)) {
    const [titleHtml, body = ''] = section.split(/<\/h2>/i);
    const title = htmlToLines(titleHtml).join(' ');
    // "Clutch Player of the Year" 같은 다른 상을 MVP로 착각하지 않도록 제목 전체로 고른다.
    const award = AWARDS.find((a) => a.resultTitle.test(title));
    if (!award || results[award.key]) continue;

    let winner = null;
    const finalists = [];
    for (const line of htmlToLines(body)) {
      const w = line.match(/Winner:\s*(.+?),\s*(.+)$/i);
      if (w) {
        const teamId = teamIdOf(w[2]);
        if (teamId) winner = { nameEn: w[1].trim(), teamId };
        continue;
      }
      const f = line.match(/^(.+?),\s*(.+?)\s*(\[winner\])?$/i);
      const teamId = f ? teamIdOf(f[2]) : null;
      if (f && teamId) finalists.push({ nameEn: f[1].trim(), teamId, isWinner: Boolean(f[3]) });
    }
    if (winner || finalists.length) results[award.key] = { winner, finalists };
  }
  return results;
}

/** NBA.com 페이지의 __NEXT_DATA__ JSON. */
function nextDataOf(html) {
  const m = String(html ?? '').match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (!m) throw new Error('NBA.com 페이지 형식이 바뀌었습니다 (__NEXT_DATA__ 없음)');
  return JSON.parse(m[1]);
}

/** 카테고리 페이지 데이터에서 기사 목록(최신순). */
function articleList(data) {
  const found = new Map();
  (function walk(node) {
    if (!node || typeof node !== 'object') return;
    if (typeof node.slug === 'string' && typeof node.date === 'string' && typeof node.title === 'string') {
      if (!found.has(node.slug)) {
        found.set(node.slug, {
          slug: node.slug,
          date: node.date,
          title: node.title,
          url: node.permalink ?? `${NBA}/news/${node.slug}`,
        });
      }
    }
    for (const value of Object.values(node)) walk(value);
  })(data);
  return [...found.values()].sort((a, b) => b.date.localeCompare(a.date));
}

async function fetchHtml(url) {
  // NBA.com은 브라우저를 흉내 낸 UA도, 봇이라고 밝힌 UA도 403으로 막고
  // Node 기본값은 통과시킨다. ESPN 수집과 같은 이유로 UA를 붙이지 않는다.
  const res = await fetch(url, { signal: AbortSignal.timeout(20000) });
  if (!res.ok) {
    const error = new Error(`HTTP ${res.status} ${url}`);
    error.status = res.status;
    throw error;
  }
  return res.text();
}

/** 한 상의 최신 사다리. 이번·지난 시즌 기사 중 순위를 뽑을 수 있는 가장 최근 것. */
async function latestLadder(award, { getHtml, teamIdOf, playerIdOf, seasons }) {
  const category = nextDataOf(await getHtml(`${NBA}/news/category/${award.category}`));
  const candidates = articleList(category)
    .filter((a) => award.slug.test(a.slug) && seasons.includes(seasonOf(a.date)))
    .slice(0, 3);

  for (const item of candidates) {
    const article = nextDataOf(await getHtml(item.url)).props?.pageProps?.article;
    if (!article) continue;
    const entries = parseLadder(article.contentFiltered, teamIdOf);
    // 순위가 셋도 안 나오면 형식이 다른 글(요약·특집)로 보고 한 주 전 것을 본다.
    if (entries.length < 3) continue;
    return {
      title: decodeEntities(article.title ?? item.title),
      url: article.permalink ?? item.url,
      publishedAt: article.date ?? item.date,
      season: seasonOf(article.date ?? item.date),
      author: article.author?.name ?? null,
      entries: entries.map((e) => ({ ...e, playerId: playerIdOf(e.nameEn, e.teamId) })),
    };
  }
  return null;
}

/**
 * 세 상(MVP·DPOY·신인왕)의 사다리와 수상 결과.
 *
 * [teams]·[players]는 번역 전 영문 데이터(기사 이름과 맞춰야 한다).
 * [previous]는 지난 실행 결과. 확인한 지 몇 시간 안 됐으면 그대로 쓰고,
 * 가져오다 실패한 부분도 지난 결과로 채워 화면이 비지 않게 한다.
 */
async function fetchAwardRaces({ teams, players, season, previous = null, now = new Date(), getHtml = fetchHtml }) {
  if (
    previous?.currentSeason === season &&
    previous.checkedAt &&
    now - new Date(previous.checkedAt) < RECHECK_MS
  ) {
    return { ...previous, reused: true };
  }

  const teamIdOf = teamMatcher(teams);
  const playerIdOf = playerMatcher(players);
  const seasons = [season, previousSeason(season)].filter(Boolean);
  const withPlayer = (c) => (c ? { ...c, playerId: playerIdOf(c.nameEn, c.teamId) } : null);

  // 수상 결과는 이번 시즌 발표가 있으면 그것, 아직이면 지난 시즌 것.
  let results = null;
  let resultsFailed = false;
  for (const s of seasons) {
    try {
      const url = awardsUrl(s);
      const article = nextDataOf(await getHtml(url)).props?.pageProps?.article;
      const parsed = parseAwardResults(article?.contentFiltered, teamIdOf);
      if (Object.keys(parsed).length) {
        results = { season: s, url: article.permalink ?? url, byAward: parsed };
        break;
      }
    } catch (error) {
      // 404는 아직 발표 전이라는 뜻이다. 그 밖의 실패는 지난 결과를 쓰게 표시한다.
      if (error.status !== 404) resultsFailed = true;
    }
  }

  const awards = [];
  for (const award of AWARDS) {
    const before = previous?.awards?.find((a) => a.award === award.key) ?? null;

    let ladder;
    try {
      ladder = await latestLadder(award, { getHtml, teamIdOf, playerIdOf, seasons });
    } catch (error) {
      console.warn(`  ${award.key} 사다리 실패: ${error.message}`);
      ladder = before?.ladder ?? null;
    }

    const r = results?.byAward[award.key];
    const result = r
      ? { season: results.season, url: results.url, winner: withPlayer(r.winner), finalists: r.finalists.map(withPlayer) }
      : resultsFailed ? before?.result ?? null : null;

    awards.push({ award: award.key, ladder, result });
  }

  return { checkedAt: now.toISOString(), currentSeason: season, awards };
}

module.exports = {
  AWARDS,
  articleList,
  awardsUrl,
  fetchAwardRaces,
  htmlToLines,
  nextDataOf,
  normalizeName,
  parseAwardResults,
  parseLadder,
  playerMatcher,
  previousSeason,
  seasonOf,
  teamMatcher,
};
