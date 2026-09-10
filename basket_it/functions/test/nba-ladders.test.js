'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  articleList,
  awardsUrl,
  fetchAwardRaces,
  htmlToLines,
  normalizeName,
  parseAwardResults,
  parseLadder,
  playerMatcher,
  previousSeason,
  seasonOf,
  teamMatcher,
} = require('../../tools/nba-ladders');

const TEAMS = [
  { id: '25', city: 'Oklahoma City', name: 'Thunder' },
  { id: '7', city: 'Denver', name: 'Nuggets' },
  { id: '24', city: 'San Antonio', name: 'Spurs' },
  { id: '12', city: 'LA', name: 'Clippers' },
  { id: '30', city: 'Charlotte', name: 'Hornets' },
  { id: '6', city: 'Dallas', name: 'Mavericks' },
  { id: '20', city: 'Philadelphia', name: '76ers' },
  { id: '2', city: 'Boston', name: 'Celtics' },
];

const PLAYERS = [
  { id: '4278073', name: 'Shai Gilgeous-Alexander', teamId: '25' },
  { id: '3112335', name: 'Nikola Jokic', teamId: '7' },
  { id: '5104157', name: 'Victor Wembanyama', teamId: '24' },
  { id: '6450', name: 'Kawhi Leonard', teamId: '12' },
  { id: '5061575', name: 'Kon Knueppel', teamId: '30' },
  { id: '5041939', name: 'Cooper Flagg', teamId: '6' },
  { id: '5124612', name: 'VJ Edgecombe', teamId: '20' },
  // 비시즌 이적: 사다리 기사는 보스턴, 지금 로스터는 필라델피아
  { id: '3917376', name: 'Jaylen Brown', teamId: '20' },
];

/** 실제 MVP 사다리 본문 형식을 줄인 것. */
const MVP_HTML = `
<p>So here’s the envelope:</p>
<hr />
<h3>1. Shai Gilgeous-Alexander, Oklahoma City Thunder</h3>
<p><a href="#"><strong>Last week</strong>’<strong>s ranking:</strong></a> No. 2 ⬆️<br />
<a href="#"><strong>Season stats:</strong></a> 31.1 points, 4.3 rebounds, 6.6 assists</p>
<p><strong>His case:</strong> 1. nobody played better, Denver knows.</p>
<hr />
<h3>2. Nikola Jokić, Denver Nuggets</h3>
<p><strong>Last week&#8217;s ranking:</strong> No. 3 ⬆️</p>
<h3>3. Victor Wembanyama, San Antonio Spurs</h3>
<p><strong>Last week's ranking:</strong> No. 1 ⬇️</p>
<h3>5. Jaylen Brown, Boston Celtics</h3>
<p><strong>Last week's ranking:</strong> Not ranked</p>
<h3>The next 5:</h3>
<p><strong>6.</strong> Kawhi Leonard, LA Clippers ⬆️<br />
<span><strong>7.</strong> Someone Retired, Seattle SuperSonics ↔️</span></p>
<p><strong>And five more (in alphabetical order): </strong>Jalen Duren, Detroit Pistons; Tyrese Maxey, Philadelphia 76ers</p>`;

/** 신인 사다리 최종판: 번호 목록 3명 + 올루키 팀(번호 없음). */
const ROY_FINAL_HTML = `
<ol>
<li><b><span> Kon Knueppel, Charlotte Hornets </span></b></li>
<li><b><span> Cooper Flagg, Dallas Mavericks</span></b></li>
<li><b><span> VJ Edgecombe, Philadelphia 76ers </span></b></li>
</ol>
<h3>All-Rookie First Team</h3>
<ul><li><b>Kon Knueppel, Charlotte Hornets</b></li></ul>`;

const AWARDS_HTML = `
<p>Below is a complete list:</p>
<h2>Kia NBA Most Valuable Player</h2>
<p><strong>&gt; Winner: </strong><a href="#"><strong>Shai Gilgeous-Alexander, Oklahoma City Thunder</strong></a></p>
<p><strong>Finalists:</strong></p>
<ul>
<li><b><b>Shai</b> Gilgeous-Alexander</b>, Oklahoma City Thunder <span><strong>[winner]</strong></span></li>
<li><strong>Nikola Jokić</strong>, Denver Nuggets</li>
<li><strong>Victor Wembanyama</strong>, San Antonio Spurs</li>
</ul>
<h2>Kia NBA Clutch Player of the Year</h2>
<p><strong>&gt; Winner:</strong> Kawhi Leonard, LA Clippers</p>
<h2>Kia NBA Defensive Player of the Year</h2>
<p><strong>Finalists:</strong></p>
<ul><li><strong>Victor Wembanyama</strong>, San Antonio Spurs</li></ul>`;

const teamIdOf = teamMatcher(TEAMS);

test('시즌 계산: 8월부터 새 시즌', () => {
  assert.equal(seasonOf('2026-04-17T11:01:29Z'), '2025-26');
  assert.equal(seasonOf('2026-11-03T00:00:00Z'), '2026-27');
  assert.equal(seasonOf('2023-04-11T00:00:00Z'), '2022-23');
  assert.equal(previousSeason('2025-26'), '2024-25');
  assert.equal(previousSeason('2000-01'), '1999-00');
  assert.equal(awardsUrl('2025-26'), 'https://www.nba.com/news/2025-2026-regular-season-awards');
});

test('이름 비교 키는 악센트·대소문자·Jr./III를 무시한다', () => {
  assert.equal(normalizeName('Nikola Jokić'), normalizeName('NIkola Jokic'));
  assert.equal(normalizeName('Jimmy Butler III'), normalizeName('Jimmy Butler'));
  assert.equal(normalizeName('Egor Dëmin'), normalizeName('Egor Demin'));
  assert.equal(normalizeName('VJ Edgecombe'), 'vjedgecombe');
});

test('LA Clippers와 Los Angeles Clippers를 같은 팀으로 본다', () => {
  assert.equal(teamIdOf('LA Clippers'), '12');
  assert.equal(teamIdOf('Los Angeles Clippers'), '12');
  assert.equal(teamIdOf('Seattle SuperSonics'), null);
});

test('MVP 사다리: 순위·지난주 순위·다음 5명을 읽고 본문 문장은 무시한다', () => {
  const entries = parseLadder(MVP_HTML, teamIdOf);
  assert.deepEqual(
    entries.map((e) => [e.rank, e.nameEn, e.teamId, e.previousRank, e.movement]),
    [
      [1, 'Shai Gilgeous-Alexander', '25', 2, 'up'],
      [2, 'Nikola Jokić', '7', 3, 'up'],
      [3, 'Victor Wembanyama', '24', 1, 'down'],
      [5, 'Jaylen Brown', '2', null, 'new'],
      [6, 'Kawhi Leonard', '12', null, 'up'],
    ],
  );
});

test('신인 사다리 최종판: 번호 목록만 순위로, 올루키 팀 목록은 무시', () => {
  const entries = parseLadder(ROY_FINAL_HTML, teamIdOf);
  assert.deepEqual(entries.map((e) => [e.rank, e.nameEn]), [
    [1, 'Kon Knueppel'],
    [2, 'Cooper Flagg'],
    [3, 'VJ Edgecombe'],
  ]);
});

test('수상 결과: 상별 수상자와 후보, 다른 상을 MVP로 착각하지 않는다', () => {
  const results = parseAwardResults(AWARDS_HTML, teamIdOf);
  assert.deepEqual(Object.keys(results).sort(), ['dpoy', 'mvp']);
  assert.deepEqual(results.mvp.winner, { nameEn: 'Shai Gilgeous-Alexander', teamId: '25' });
  assert.deepEqual(
    results.mvp.finalists.map((f) => [f.nameEn, f.isWinner]),
    [['Shai Gilgeous-Alexander', true], ['Nikola Jokić', false], ['Victor Wembanyama', false]],
  );
  // 발표 전이면 수상자 없이 후보만
  assert.equal(results.dpoy.winner, null);
  assert.equal(results.dpoy.finalists.length, 1);
});

test('선수 매칭: 이적한 선수도 이름으로 찾고, 동명이인은 팀으로 가른다', () => {
  const players = [...PLAYERS, { id: 'dup', name: 'Kawhi Leonard', teamId: '99' }];
  const idOf = playerMatcher(players);
  assert.equal(idOf('Jaylen Brown', '2'), '3917376');
  assert.equal(idOf('Nikola Jokić', '7'), '3112335');
  assert.equal(idOf('Kawhi Leonard', '99'), 'dup');
  assert.equal(idOf('Nobody Here', '7'), null);
});

test('HTML 엔티티와 <br> 줄바꿈을 푼다', () => {
  assert.deepEqual(htmlToLines('<p>A&#8217;s &amp; B<br />C</p>'), ['A’s & B', 'C']);
});

function page(data) {
  return `<html><script id="__NEXT_DATA__" type="application/json">${JSON.stringify(data)}</script></html>`;
}

function articlePage({ title, slug, date, html }) {
  return page({
    props: {
      pageProps: {
        article: {
          title,
          slug,
          date,
          permalink: `https://www.nba.com/news/${slug}`,
          author: { name: 'Shaun Powell' },
          contentFiltered: html,
        },
      },
    },
  });
}

test('카테고리 페이지에서 기사 목록을 최신순으로', () => {
  const list = articleList({
    props: {
      pageProps: {
        layout: { items: [{ slug: 'old', date: '2026-03-01T00:00:00Z', title: 'Old' }] },
        more: [{ slug: 'new', date: '2026-04-01T00:00:00Z', title: 'New', permalink: 'https://x/new' }],
      },
    },
  });
  assert.deepEqual(list.map((a) => a.slug), ['new', 'old']);
  assert.equal(list[1].url, 'https://www.nba.com/news/old');
});

function fakeSite() {
  const requested = [];
  const pages = {
    'https://www.nba.com/news/category/kia-race-to-the-mvp-ladder': page({
      items: [
        // 파이널 MVP 사다리는 정규시즌 MVP가 아니다
        { slug: 'finals-mvp-ladder-june-10-2026', date: '2026-06-09T00:00:00Z', title: 'Finals' },
        { slug: 'kia-mvp-ladder-updates-2025-26', date: '2026-04-18T00:00:00Z', title: 'Tracker' },
        { slug: 'kia-mvp-ladder-april-17-2026-edition', date: '2026-04-17T11:01:29Z', title: 'Final' },
      ],
    }),
    'https://www.nba.com/news/kia-mvp-ladder-april-17-2026-edition': articlePage({
      title: 'Kia MVP Ladder: final pick',
      slug: 'kia-mvp-ladder-april-17-2026-edition',
      date: '2026-04-17T11:01:29Z',
      html: MVP_HTML,
    }),
    // DPOY 사다리는 2023년이 마지막이다
    'https://www.nba.com/news/category/defensive-player-ladder': page({
      items: [{ slug: 'defensive-player-ladder-april-2023-edition', date: '2023-04-11T00:00:00Z', title: 'Old' }],
    }),
    'https://www.nba.com/news/category/kia-rookie-ladder': page({
      items: [{ slug: 'kia-rookie-ladder-april-8-2026', date: '2026-04-08T00:00:00Z', title: 'ROY' }],
    }),
    'https://www.nba.com/news/kia-rookie-ladder-april-8-2026': articlePage({
      title: 'Kia Rookie Ladder: final',
      slug: 'kia-rookie-ladder-april-8-2026',
      date: '2026-04-08T00:00:00Z',
      html: ROY_FINAL_HTML,
    }),
    'https://www.nba.com/news/2025-2026-regular-season-awards': articlePage({
      title: 'Awards',
      slug: '2025-2026-regular-season-awards',
      date: '2026-05-20T00:00:00Z',
      html: AWARDS_HTML,
    }),
  };
  async function getHtml(url) {
    requested.push(url);
    if (!(url in pages)) {
      const error = new Error(`HTTP 404 ${url}`);
      error.status = 404;
      throw error;
    }
    return pages[url];
  }
  return { getHtml, requested };
}

test('세 상의 레이스를 모은다: DPOY는 오래된 사다리 대신 수상 결과만', async () => {
  const { getHtml } = fakeSite();
  const races = await fetchAwardRaces({
    teams: TEAMS,
    players: PLAYERS,
    season: '2025-26',
    now: new Date('2026-09-10T00:00:00Z'),
    getHtml,
  });
  const byKey = Object.fromEntries(races.awards.map((a) => [a.award, a]));

  assert.equal(byKey.mvp.ladder.url, 'https://www.nba.com/news/kia-mvp-ladder-april-17-2026-edition');
  assert.equal(byKey.mvp.ladder.season, '2025-26');
  assert.equal(byKey.mvp.ladder.author, 'Shaun Powell');
  assert.equal(byKey.mvp.ladder.entries[0].playerId, '4278073');
  assert.equal(byKey.mvp.result.winner.playerId, '4278073');

  assert.equal(byKey.dpoy.ladder, null);
  assert.equal(byKey.dpoy.result.finalists[0].playerId, '5104157');

  assert.deepEqual(byKey.roy.ladder.entries.map((e) => e.playerId), ['5061575', '5041939', '5124612']);
  // 신인왕 결과는 이 발표 기사에 없다
  assert.equal(byKey.roy.result, null);
});

test('확인한 지 3시간이 안 됐으면 NBA.com에 다시 요청하지 않는다', async () => {
  const { getHtml, requested } = fakeSite();
  const previous = { checkedAt: '2026-09-10T00:00:00Z', currentSeason: '2025-26', awards: [] };
  const races = await fetchAwardRaces({
    teams: TEAMS,
    players: PLAYERS,
    season: '2025-26',
    previous,
    now: new Date('2026-09-10T02:00:00Z'),
    getHtml,
  });
  assert.equal(races.reused, true);
  assert.equal(requested.length, 0);
});

test('사다리를 못 가져오면 지난 결과를 지우지 않는다', async () => {
  const previousLadder = { url: 'https://x/old', season: '2025-26', entries: [{ rank: 1, nameEn: 'A' }] };
  const races = await fetchAwardRaces({
    teams: TEAMS,
    players: PLAYERS,
    season: '2025-26',
    previous: {
      checkedAt: '2026-09-01T00:00:00Z',
      currentSeason: '2025-26',
      awards: [{ award: 'mvp', ladder: previousLadder, result: null }],
    },
    now: new Date('2026-09-10T00:00:00Z'),
    getHtml: async () => {
      throw new Error('network down');
    },
  });
  assert.deepEqual(races.awards.find((a) => a.award === 'mvp').ladder, previousLadder);
});
