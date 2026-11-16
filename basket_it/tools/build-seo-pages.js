#!/usr/bin/env node
'use strict';

/**
 * 검색엔진이 읽을 수 있는 정적 소개 페이지를 만든다.
 *
 * 앱(Flutter 웹)은 화면을 캔버스에 그려 구글이 글자를 읽지 못한다. 그래서
 * 서비스 소개(/about/), KBL 구단(/kbl/), 구단별 선수 명단(/kbl/{팀}/)을 보통
 * HTML로 따로 두고 사이트맵에 올린다. 내용은 수집 데이터(GitHub Pages)에서 만든다.
 * 선수 명단이 바뀌면 다시 돌린 뒤 배포한다.
 *
 * 사용: node tools/build-seo-pages.js   (web/ 아래에 쓴다)
 */

const fs = require('fs');
const path = require('path');

const SITE = 'https://basket-it-kbl.web.app';
const DATA = 'https://junmin061101-del.github.io/Basketball-Application/kbl';
const WEB = path.join(__dirname, '..', 'web');

/** 구단 정식 이름(연고지 + 모기업 + 애칭). 검색할 때 흔히 쓰는 이름이다. */
const CLUBS = {
  sk: { full: '서울 SK 나이츠', nick: '나이츠' },
  kgc: { full: '안양 정관장 레드부스터스', nick: '레드부스터스' },
  db: { full: '원주 DB 프로미', nick: '프로미' },
  lg: { full: '창원 LG 세이커스', nick: '세이커스' },
  kcc: { full: '부산 KCC 이지스', nick: '이지스' },
  kt: { full: '수원 KT 소닉붐', nick: '소닉붐' },
  kogas: { full: '대구 한국가스공사 페가수스', nick: '페가수스' },
  sono: { full: '고양 소노 스카이거너스', nick: '스카이거너스' },
  mobis: { full: '울산 현대모비스 피버스', nick: '피버스' },
  samsung: { full: '서울 삼성 썬더스', nick: '썬더스' },
};

const POSITIONS = { pg: '포인트가드', sg: '슈팅가드', sf: '스몰포워드', pf: '파워포워드', c: '센터' };

/** 받침이 있으면 a, 없으면 b(원주"를", 서울"을"). 영문 약어는 읽는 소리로(SK"는", LG"는"). */
function josa(word, a, b) {
  const last = String(word).trim().slice(-1);
  const code = last.charCodeAt(0);
  const batchim = code >= 0xac00 && code <= 0xd7a3 ? (code - 0xac00) % 28 !== 0 : /[LMNR0136789]/i.test(last);
  return batchim ? a : b;
}

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

function page({ urlPath, title, description, body, jsonLd }) {
  const url = `${SITE}${urlPath}`;
  return `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<meta name="description" content="${esc(description)}">
<link rel="canonical" href="${url}">
<link rel="icon" type="image/png" sizes="192x192" href="/icons/Icon-192.png">
<link rel="icon" type="image/png" sizes="48x48" href="/favicon-48.png">
<link rel="apple-touch-icon" href="/icons/apple-touch-icon.png">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Baskit">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(description)}">
<meta property="og:url" content="${url}">
<meta property="og:image" content="${SITE}/icons/Icon-512.png">
<meta property="og:locale" content="ko_KR">
${jsonLd ? `<script type="application/ld+json">${JSON.stringify(jsonLd)}</script>` : ''}
<style>
  :root { --o:#F97316; --t:#111827; --s:#6B7280; --b:#E5E7EB; --bg:#FFFFFF; --sf:#F9FAFB; }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--t); font-family: Pretendard, -apple-system, BlinkMacSystemFont, 'Apple SD Gothic Neo', 'Malgun Gothic', sans-serif; line-height:1.6; }
  header { display:flex; align-items:center; gap:10px; padding:14px 16px; border-bottom:1px solid var(--b); }
  header a.brand { display:flex; align-items:center; gap:10px; color:var(--t); text-decoration:none; font-weight:900; font-size:20px; }
  header img { width:34px; height:34px; border-radius:9px; }
  header nav { margin-left:auto; display:flex; gap:14px; font-size:14px; }
  header nav a { color:var(--s); text-decoration:none; }
  main { max-width:760px; margin:0 auto; padding:24px 16px 48px; }
  h1 { font-size:26px; line-height:1.3; margin:8px 0 10px; }
  h2 { font-size:19px; margin:32px 0 10px; }
  p, li { color:#374151; }
  .cta { display:inline-block; margin:14px 0 6px; padding:12px 18px; border-radius:12px; background:var(--o); color:#fff; font-weight:800; text-decoration:none; }
  .grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(220px, 1fr)); gap:10px; padding:0; list-style:none; }
  .grid li a { display:block; padding:14px; border:1px solid var(--b); border-radius:12px; color:var(--t); text-decoration:none; background:var(--sf); }
  .grid li a small { display:block; color:var(--s); }
  table { width:100%; border-collapse:collapse; font-size:15px; }
  th, td { text-align:left; padding:9px 8px; border-bottom:1px solid var(--b); }
  th { color:var(--s); font-weight:600; font-size:13px; }
  footer { border-top:1px solid var(--b); padding:20px 16px 32px; text-align:center; font-size:13px; color:var(--s); }
  footer a { color:var(--s); }
</style>
</head>
<body>
<header>
  <a class="brand" href="/"><img src="/icons/Icon-192.png" alt="Baskit 로고" width="34" height="34">Baskit</a>
  <nav><a href="/about/">소개</a><a href="/kbl/">KBL 구단</a><a href="/">앱 열기</a></nav>
</header>
<main>
${body}
</main>
<footer>
  <p><a href="/">Baskit(바스킷)</a> · KBL 농구 실시간 경기·기록·승부예측 · <a href="/about/">서비스 소개</a> · <a href="/kbl/">KBL 구단·선수</a></p>
</footer>
</body>
</html>
`;
}

const cta = '<a class="cta" href="/">Baskit에서 실시간으로 보기</a>';

function aboutPage(teams) {
  const faq = [
    ['Baskit(바스킷)은 어떤 앱인가요?', 'KBL 프로농구 팬을 위한 무료 농구 앱이에요. 경기 일정과 결과, 실시간 점수, 팀 순위, 선수 기록, 승부예측, 농구 커뮤니티, KBL·NBA 농구 뉴스를 한곳에서 볼 수 있어요.'],
    ['농구 실시간 경기 점수를 볼 수 있나요?', '네. KBL 경기가 진행되는 동안 쿼터와 남은 시간, 점수, 선수별 득점·리바운드·어시스트 기록을 30초마다 갱신해 보여줘요. 아이폰 잠금화면 실시간 현황도 지원해요.'],
    ['설치해야 하나요?', '설치 없이 웹(basket-it-kbl.web.app)에서 바로 쓸 수 있어요. 휴대폰 홈 화면에 추가하면 앱처럼 쓸 수 있어요.'],
    ['NBA 소식도 볼 수 있나요?', '네. NBA 농구 뉴스를 KBL 뉴스와 따로 모아 보여주고, 커뮤니티에도 NBA 게시판이 있어요.'],
    ['승부예측은 어떻게 하나요?', '경기 시작 1시간 전까지 이길 팀을 고르면 돼요. 경기가 끝나면 적중 수로 랭킹이 매겨져요.'],
  ];
  const body = `
<h1>Baskit(바스킷) — KBL 농구 실시간 경기·기록·승부예측 앱</h1>
<p>Baskit은 한국 프로농구 KBL 팬을 위한 농구 앱이에요. 오늘 농구 경기 일정과 실시간 점수, KBL 순위, 선수 기록, 승부예측, 농구 커뮤니티, NBA 뉴스까지 한곳에서 볼 수 있어요.</p>
${cta}
<h2>이런 걸 할 수 있어요</h2>
<ul>
  <li><strong>농구 실시간 경기</strong> — 쿼터·남은 시간·점수와 선수별 박스스코어(득점, 리바운드, 어시스트, 스틸, 블록)</li>
  <li><strong>KBL 경기 일정·결과</strong> — 날짜별 일정, 경기 결과, 문자중계</li>
  <li><strong>KBL 순위</strong> — 팀 순위, 승패, 승차, 연승·연패</li>
  <li><strong>선수 기록</strong> — 시즌 평균, 경기별 기록, 시즌별 기록, 부문별 랭킹(득점·리바운드·어시스트 등)</li>
  <li><strong>승부예측</strong> — 경기마다 이길 팀을 고르고 적중 랭킹으로 겨루기</li>
  <li><strong>농구 커뮤니티</strong> — KBL·NBA 게시판에서 응원, 분석, 질문</li>
  <li><strong>농구 뉴스</strong> — KBL 뉴스와 NBA 뉴스, 내 팀·내 선수 소식</li>
  <li><strong>내 팀 팔로우</strong> — 응원하는 구단의 일정·순위·주요 선수를 홈 첫 화면에</li>
</ul>
<h2>KBL 10개 구단</h2>
<ul class="grid">
${teams.map((t) => `  <li><a href="/kbl/${t.id}/">${esc(CLUBS[t.id]?.full ?? t.name)}<small>선수 명단 보기</small></a></li>`).join('\n')}
</ul>
<h2>자주 묻는 질문</h2>
${faq.map(([q, a]) => `<h3>${esc(q)}</h3>\n<p>${esc(a)}</p>`).join('\n')}
${cta}
`;
  return page({
    urlPath: '/about/',
    title: 'Baskit(바스킷) 소개 — KBL 농구 실시간 경기·순위·선수 기록 앱',
    description: 'Baskit(바스킷)은 KBL 프로농구 팬을 위한 무료 농구 앱이에요. 실시간 경기 점수, 경기 일정, 팀 순위, 선수 기록, 승부예측, 농구 커뮤니티, NBA 뉴스를 한곳에서.',
    body,
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'FAQPage',
      mainEntity: faq.map(([q, a]) => ({ '@type': 'Question', name: q, acceptedAnswer: { '@type': 'Answer', text: a } })),
    },
  });
}

function kblPage(teams, playersByTeam) {
  const body = `
<h1>KBL 10개 구단과 선수 명단</h1>
<p>2026-27 시즌 한국 프로농구 KBL 10개 구단과 소속 선수예요. 구단을 누르면 선수 명단(포지션·등번호)을 볼 수 있어요. 경기 일정·실시간 점수·순위는 Baskit 앱에서 볼 수 있어요.</p>
${cta}
<ul class="grid">
${teams.map((t) => `  <li><a href="/kbl/${t.id}/">${esc(CLUBS[t.id]?.full ?? t.name)}<small>선수 ${(playersByTeam[t.id] ?? []).length}명 · 연고지 ${esc(t.city)}</small></a></li>`).join('\n')}
</ul>
`;
  return page({
    urlPath: '/kbl/',
    title: 'KBL 구단·선수 명단 — 10개 구단 프로농구 | Baskit',
    description: 'KBL 프로농구 10개 구단(서울 SK, 안양 정관장, 원주 DB, 창원 LG, 부산 KCC, 수원 KT, 대구 한국가스공사, 고양 소노, 울산 현대모비스, 서울 삼성)과 선수 명단.',
    body,
  });
}

function teamPage(team, players) {
  const club = CLUBS[team.id] ?? { full: `${team.city} ${team.name}`, nick: '' };
  const sorted = [...players].sort((a, b) => a.backNumber - b.backNumber);
  const names = sorted.slice(0, 5).map((p) => p.name).join(', ');
  const body = `
<h1>${esc(club.full)} 선수 명단</h1>
<p>${esc(club.full)}(${esc(team.shortName)})${josa(team.shortName, '은', '는')} ${esc(team.city)}${josa(team.city, '을', '를')} 연고지로 하는 KBL 프로농구 구단이에요. 2026-27 시즌 선수 ${sorted.length}명의 포지션과 등번호예요. ${esc(team.shortName)} 경기 일정, 실시간 점수, 순위, 선수 기록은 Baskit에서 볼 수 있어요.</p>
${cta}
<h2>선수 명단</h2>
<table>
<thead><tr><th>등번호</th><th>선수</th><th>포지션</th></tr></thead>
<tbody>
${sorted.map((p) => `<tr><td>${esc(p.backNumber)}</td><td>${esc(p.name)}</td><td>${esc(p.positionLabel ?? POSITIONS[p.position] ?? '')}</td></tr>`).join('\n')}
</tbody>
</table>
<p><a href="/kbl/">← KBL 10개 구단 보기</a></p>
`;
  return page({
    urlPath: `/kbl/${team.id}/`,
    title: `${club.full} 선수 명단·경기 일정 | Baskit`,
    description: `${club.full} 2026-27 시즌 선수 명단(${names} 등)과 포지션·등번호. ${team.shortName} 실시간 경기 점수, 순위, 선수 기록은 Baskit(바스킷)에서.`,
    body,
    jsonLd: {
      '@context': 'https://schema.org',
      '@type': 'SportsTeam',
      name: club.full,
      alternateName: [team.shortName, club.nick].filter(Boolean),
      sport: 'Basketball',
      memberOf: { '@type': 'SportsOrganization', name: 'KBL' },
      athlete: sorted.map((p) => ({ '@type': 'Person', name: p.name })),
    },
  });
}

async function main() {
  const get = (name) => fetch(`${DATA}/${name}.json`).then((r) => {
    if (!r.ok) throw new Error(`${name}.json HTTP ${r.status}`);
    return r.json();
  });
  const [{ teams }, { players }] = await Promise.all([get('teams'), get('players')]);
  const playersByTeam = {};
  for (const p of players) (playersByTeam[p.teamId] ??= []).push(p);

  const write = (rel, html) => {
    const file = path.join(WEB, rel);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, html);
  };
  write('about/index.html', aboutPage(teams));
  write('kbl/index.html', kblPage(teams, playersByTeam));
  for (const t of teams) write(`kbl/${t.id}/index.html`, teamPage(t, playersByTeam[t.id] ?? []));

  const urls = ['/', '/about/', '/kbl/', ...teams.map((t) => `/kbl/${t.id}/`)];
  write('sitemap.xml', `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map((u) => `  <url>\n    <loc>${SITE}${u}</loc>\n  </url>`).join('\n')}
</urlset>
`);
  console.log(`페이지 ${2 + teams.length}개, 선수 ${players.length}명, 사이트맵 ${urls.length}개 주소`);
}

main().catch((e) => {
  console.error('실패:', e.message);
  process.exit(1);
});
