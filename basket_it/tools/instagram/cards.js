#!/usr/bin/env node
'use strict';

/**
 * 인스타그램 카드(1080×1350 PNG)를 만든다.
 *
 *   node tools/instagram/cards.js game [경기 id]      경기 결과(빼면 가장 최근 경기)
 *   node tools/instagram/cards.js today [YYYY-MM-DD]  오늘의 경기(빼면 오늘)
 *   node tools/instagram/cards.js standings           KBL 순위
 *   node tools/instagram/cards.js leaders             득점·리바운드·어시스트 TOP 5(3장)
 *   node tools/instagram/cards.js news                KBL 뉴스 브리핑
 *
 * 우리가 모은 데이터(GitHub Pages)로만 만든다. 팀 로고·선수 사진·기사 사진은 사용
 * 허가 전이라 쓰지 않고 팀색으로 구분한다. 배경은 두 색을 대각선으로 나눈다(앱의
 * 경기 날 카드와 같은 느낌). HTML을 Playwright(Chromium)로 찍는다. 글꼴은 앱과 같은
 * Pretendard(assets/fonts). 출력은 build/cards/.
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const PAGES = 'https://junmin061101-del.github.io/Basketball-Application';
const FONTS = path.join(__dirname, '..', '..', 'assets', 'fonts');
const OUT = path.join(__dirname, '..', '..', 'build', 'cards');
const WEEKDAYS = ['일', '월', '화', '수', '목', '금', '토'];
const BRAND = '#F97316';
const NAVY = '#0F172A';
/** 긴 구단 이름은 팬들이 부르는 이름으로(앱의 team_label.dart와 같다). */
const SHORT = { 한국가스공사: '페가수스', 현대모비스: '모비스' };

const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const getJson = (p) => fetch(`${PAGES}/${p}.json`).then((r) => {
  if (!r.ok) throw new Error(`${p}.json HTTP ${r.status}`);
  return r.json();
});
const short = (team) => SHORT[team.shortName] ?? team.shortName;

/** 한국 시각 Date의 "11.18 (수)". */
function kstLabel(date) {
  const k = new Date(date.getTime() + 9 * 3600e3);
  return `${k.getUTCMonth() + 1}.${k.getUTCDate()} (${WEEKDAYS[k.getUTCDay()]})`;
}
const kstDay = (date) => new Date(date.getTime() + 9 * 3600e3).toISOString().slice(0, 10);

/** 순위표: 승률 순으로 매긴 { teamId: {rank, wins, losses, gamesBehind} }. */
function rankTable(standings) {
  const pct = (s) => s.wins / (s.wins + s.losses || 1);
  const rows = [...(standings.standings ?? [])].sort((a, b) => pct(b) - pct(a) || b.wins - a.wins);
  return rows.map((s, i) => ({ ...s, rank: i + 1, pct: pct(s) }));
}

// ---------------------------------------------------------------- 공통 틀

const LOGO = '<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 2v20M2 12h20M5 5c3 3 3 11 0 14M19 5c-3 3-3 11 0 14"/></svg>';

function frame({ colors: [a, b], meta, kicker, title, body, css = '' }) {
  const font = (w, file) => `@font-face{font-family:P;font-weight:${w};src:url("file://${path.join(FONTS, file)}")}`;
  return `<!doctype html><html><head><meta charset="utf-8"><style>
${font(400, 'Pretendard-Regular.otf')}${font(600, 'Pretendard-SemiBold.otf')}${font(700, 'Pretendard-Bold.otf')}${font(800, 'Pretendard-ExtraBold.otf')}
*{box-sizing:border-box;margin:0}
body{width:1080px;height:1350px;font-family:P,sans-serif;color:#fff;display:flex;flex-direction:column;padding:64px 60px 60px;
  background:linear-gradient(135deg,${a} 0%,${a} 50%,${b} 50%,${b} 100%)}
.head{display:flex;align-items:center;justify-content:space-between}
.brand{display:flex;align-items:center;gap:16px;font-size:40px;font-weight:800}
.logo{width:64px;height:64px;border-radius:16px;background:${a === BRAND ? NAVY : BRAND};display:flex;align-items:center;justify-content:center}
.meta{text-align:right;font-size:28px;font-weight:600;color:rgba(255,255,255,.85);line-height:1.35}
.kicker{margin-top:56px;font-size:30px;font-weight:800;letter-spacing:6px}
.title{margin-top:8px;font-size:64px;font-weight:800;letter-spacing:-1px}
.panel{margin-top:44px;flex:1;background:rgba(15,23,42,.8);border-radius:32px;padding:20px 40px;display:flex;flex-direction:column}
.num{font-variant-numeric:tabular-nums}
.dim{color:#E2E8F0}
.chip{display:inline-block;width:14px;height:44px;border-radius:7px;vertical-align:middle}
${css}
</style></head><body>
  <div class="head"><div class="brand"><div class="logo">${LOGO}</div>Baskit</div><div class="meta">${meta}</div></div>
  <div class="kicker">${kicker}</div>
  <div class="title">${title}</div>
  ${body}
</body></html>`;
}

async function render(cards) {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1080, height: 1350 } });
  const files = [];
  for (const { name, html } of cards) {
    const htmlFile = path.join(OUT, `${name}.html`);
    fs.writeFileSync(htmlFile, html);
    await page.goto(`file://${htmlFile}`);
    await page.evaluate(() => document.fonts.ready);
    const png = path.join(OUT, `${name}.png`);
    await page.screenshot({ path: png });
    files.push(png);
  }
  await browser.close();
  return files;
}

// ---------------------------------------------------------------- 경기 결과

/** 팀에서 가장 활약한 선수: 득점 → 리바운드 → 어시스트 순. */
function topPlayer(lines, teamId) {
  return lines
    .filter((l) => l.teamId === teamId)
    .sort((a, b) => b.points - a.points || (b.oreb + b.dreb) - (a.oreb + a.dreb) || b.ast - a.ast)[0];
}

/** 팀 합계: 야투율, 3점슛, 리바운드, 어시스트. 기록이 없으면 null. */
function teamTotals(lines, teamId) {
  const mine = lines.filter((l) => l.teamId === teamId);
  if (!mine.length) return null;
  const sum = (k) => mine.reduce((n, l) => n + (l[k] ?? 0), 0);
  const fga = sum('fga');
  return [
    ['야투율', fga ? `${Math.round((sum('fgm') / fga) * 100)}%` : '-'],
    ['3점슛', `${sum('tpm')}개`],
    ['리바운드', `${sum('oreb') + sum('dreb')}`],
    ['어시스트', `${sum('ast')}`],
  ];
}

async function gameCards(wantId) {
  const [{ games }, { teams }, standings] = await Promise.all([getJson('kbl/games'), getJson('kbl/teams'), getJson('kbl/standings')]);
  const finished = games.filter((g) => g.status === 'finished').sort((a, b) => a.startTime.localeCompare(b.startTime));
  const game = wantId ? games.find((g) => g.id === wantId) : finished.at(-1);
  if (!game) throw new Error('경기를 찾지 못했어요');
  const box = await getJson(`kbl/boxscores/${game.id}`).catch(() => ({ lines: [] }));
  const teamById = Object.fromEntries(teams.map((t) => [t.id, t]));
  const rankOf = Object.fromEntries(rankTable(standings).map((r) => [r.teamId, r]));
  const [home, away] = [teamById[game.homeTeamId], teamById[game.awayTeamId]];
  const homeWon = game.homeScore > game.awayScore;

  const side = (team, score, won) => {
    const top = topPlayer(box.lines, team.id);
    const totals = teamTotals(box.lines, team.id);
    const rank = rankOf[team.id];
    return `
    <div class="side">
      <div class="band">
        <div class="city">${esc(team.city)}</div>
        <div class="name">${esc(short(team))}</div>
        ${rank ? `<div class="rec">${rank.rank}위 · ${rank.wins}승 ${rank.losses}패</div>` : ''}
      </div>
      <div class="score num ${won ? '' : 'lose'}">${score}</div>
      <div class="tag ${won ? '' : 'ghost'}">${won ? 'WIN' : '&nbsp;'}</div>
      ${totals ? `<div class="stats">${totals.map(([k, v]) => `<div><span>${k}</span><b class="num">${v}</b></div>`).join('')}</div>` : ''}
      ${top ? `<div class="top"><div class="lbl">최다 득점</div><div class="pname">${esc(top.name)}</div>
        <div class="line"><b>${top.points}</b>점 <b>${top.oreb + top.dreb}</b>리바 <b>${top.ast}</b>어시</div></div>` : ''}
    </div>`;
  };

  const html = frame({
    colors: [home.color, away.color],
    meta: `KBL 정규시즌<br>${kstLabel(new Date(game.startTime))}`,
    kicker: 'FINAL',
    title: `${esc(short(home))} ${game.homeScore} : ${game.awayScore} ${esc(short(away))}`,
    body: `<div class="board">${side(home, game.homeScore, homeWon)}${side(away, game.awayScore, !homeWon)}</div>`,
    css: `
.board{margin-top:44px;display:flex;gap:28px;flex:1}
.side{flex:1;background:rgba(15,23,42,.8);border-radius:32px;overflow:hidden;display:flex;flex-direction:column;align-items:center}
.band{width:100%;padding:30px 24px 26px;text-align:center}
.city{font-size:28px;font-weight:600;opacity:.85}
.name{font-size:56px;font-weight:800;line-height:1.15;letter-spacing:-1px}
.rec{margin-top:6px;font-size:24px;font-weight:600;opacity:.85}
.score{margin-top:34px;font-size:168px;font-weight:800;line-height:1;letter-spacing:-4px}
.score.lose{color:rgba(255,255,255,.7)}
.tag{margin-top:14px;padding:6px 20px;border-radius:999px;background:${BRAND};font-size:24px;font-weight:800;letter-spacing:3px}
.tag.ghost{background:transparent}
.stats{margin-top:30px;width:100%;padding:0 40px;display:grid;grid-template-columns:1fr 1fr;gap:14px 24px}
.stats div{display:flex;justify-content:space-between;align-items:baseline;font-size:26px;color:#E2E8F0}
.stats b{font-size:32px;font-weight:800;color:#fff}
.top{margin-top:auto;width:100%;padding:28px 24px 34px;border-top:2px solid rgba(255,255,255,.18);text-align:center}
.lbl{font-size:24px;font-weight:600;color:#E2E8F0}
.pname{margin-top:6px;font-size:44px;font-weight:800}
.line{margin-top:6px;font-size:28px;color:#F1F5F9}
.line b{color:#fff;font-weight:800;font-size:34px}`,
  });
  return [{ name: `game-${game.id}`, html }];
}

// ---------------------------------------------------------------- 오늘의 경기

async function todayCards(day = kstDay(new Date())) {
  const [{ games }, { teams }, standings] = await Promise.all([getJson('kbl/games'), getJson('kbl/teams'), getJson('kbl/standings')]);
  const teamById = Object.fromEntries(teams.map((t) => [t.id, t]));
  const rankOf = Object.fromEntries(rankTable(standings).map((r) => [r.teamId, r]));
  const todays = games
    .filter((g) => kstDay(new Date(g.startTime)) === day)
    .sort((a, b) => a.startTime.localeCompare(b.startTime));
  if (!todays.length) return [];

  const teamCell = (t, align) => {
    const r = rankOf[t.id];
    return `<div class="t ${align}"><div class="tn"><span class="chip" style="background:${t.color}"></span>${esc(short(t))}</div>
      <div class="tr dim">${r ? `${r.rank}위 · ${r.wins}승 ${r.losses}패` : ''}</div></div>`;
  };
  const time = (g) => {
    const k = new Date(new Date(g.startTime).getTime() + 9 * 3600e3);
    return `${String(k.getUTCHours()).padStart(2, '0')}:${String(k.getUTCMinutes()).padStart(2, '0')}`;
  };
  const rows = todays.map((g) => `
    <div class="row">
      ${teamCell(teamById[g.homeTeamId], 'l')}
      <div class="mid"><div class="time num">${time(g)}</div><div class="vs dim">홈 · 원정</div></div>
      ${teamCell(teamById[g.awayTeamId], 'r')}
    </div>`).join('');

  return [{
    name: `today-${day}`,
    html: frame({
      colors: [BRAND, NAVY],
      meta: `KBL 정규시즌<br>${kstLabel(new Date(`${day}T12:00:00+09:00`))}`,
      kicker: 'TODAY',
      title: `오늘의 경기 ${todays.length}`,
      body: `<div class="panel">${rows}</div>`,
      css: `
.panel{flex:0 0 auto;padding:12px 40px}
.row{display:flex;align-items:center;padding:40px 0;border-bottom:2px solid rgba(255,255,255,.12)}
.row:last-child{border-bottom:0}
.t{flex:1}.t.r{text-align:right}
.tn{font-size:46px;font-weight:800;display:flex;align-items:center;gap:16px}
.t.r .tn{flex-direction:row-reverse}
.tr{margin-top:6px;font-size:24px}
.mid{width:220px;text-align:center}
.time{font-size:52px;font-weight:800}
.vs{font-size:22px;margin-top:2px}`,
    }),
  }];
}

// ---------------------------------------------------------------- 순위

async function standingsCards() {
  const [{ teams }, standings] = await Promise.all([getJson('kbl/teams'), getJson('kbl/standings')]);
  const teamById = Object.fromEntries(teams.map((t) => [t.id, t]));
  const rows = rankTable(standings);
  const gb = (r) => (r.rank === 1 ? '-' : ((rows[0].wins - r.wins + r.losses - rows[0].losses) / 2).toFixed(1));
  const body = rows.map((r) => {
    const t = teamById[r.teamId];
    return `${r.rank === 7 ? '<div class="cut">6강 플레이오프</div>' : ''}
    <div class="row ${r.rank <= 6 ? '' : 'out'}">
      <div class="rk num">${r.rank}</div>
      <div class="tm"><span class="chip" style="background:${t.color}"></span>${esc(t.city)} ${esc(short(t))}</div>
      <div class="c num">${r.wins}</div><div class="c num">${r.losses}</div>
      <div class="c num">${r.pct.toFixed(3).replace(/^0/, '')}</div><div class="c num">${gb(r)}</div>
    </div>`;
  }).join('');
  return [{
    name: `standings-${kstDay(new Date())}`,
    html: frame({
      colors: [BRAND, NAVY],
      meta: `2026-27 정규시즌<br>${kstLabel(new Date())} 기준`,
      kicker: 'STANDINGS',
      title: 'KBL 순위',
      body: `<div class="panel"><div class="row hd dim"><div class="rk">순위</div><div class="tm">팀</div>
        <div class="c">승</div><div class="c">패</div><div class="c">승률</div><div class="c">승차</div></div>${body}</div>`,
      css: `
.row{display:flex;align-items:center;height:76px;font-size:34px;font-weight:700}
.row.hd{height:56px;font-size:24px;font-weight:600}
.row.out{color:rgba(255,255,255,.7)}
.rk{width:84px;font-weight:800}
.tm{flex:1;display:flex;align-items:center;gap:16px}
.tm .chip{height:36px}
.c{width:110px;text-align:right}
.cut{margin:4px 0;padding-top:8px;border-top:2px dashed rgba(255,255,255,.35);font-size:20px;font-weight:700;color:${BRAND}}`,
    }),
  }];
}

// ---------------------------------------------------------------- 기록 TOP 5

async function leaderCards() {
  const [{ teams }, { leaders, season }, { players }] = await Promise.all([getJson('kbl/teams'), getJson('kbl/leaders'), getJson('kbl/players')]);
  const teamById = Object.fromEntries(teams.map((t) => [t.id, t]));
  const nameOf = Object.fromEntries(players.map((p) => [p.id, p.name]));
  // 시즌 초 한두 경기만 뛴 선수가 1위에 오르지 않게, 가장 많이 뛴 선수의 절반
  // 이상 출전한 선수만 줄 세운다(카드 전용 기준. 앱 랭킹은 거르지 않는다).
  const maxGames = Math.max(...leaders.map((l) => l.gamesPlayed));
  const pool = leaders.filter((l) => l.gamesPlayed >= maxGames / 2 && nameOf[l.playerId]);
  const cats = [
    ['points', '득점', 'POINTS'],
    ['reb', '리바운드', 'REBOUNDS'],
    ['ast', '어시스트', 'ASSISTS'],
  ];
  return cats.map(([key, label, en]) => {
    const top = [...pool].sort((a, b) => b[key] - a[key]).slice(0, 5);
    const lead = teamById[top[0].teamId];
    const rows = top.map((l, i) => {
      const t = teamById[l.teamId];
      return `<div class="row ${i === 0 ? 'first' : ''}">
        <div class="rk num">${i + 1}</div>
        <div class="who"><div class="pn">${esc(nameOf[l.playerId])}</div>
          <div class="pt dim"><span class="chip" style="background:${t.color}"></span>${esc(t.city)} ${esc(short(t))} · ${l.gamesPlayed}경기</div></div>
        <div class="v num">${l[key].toFixed(1)}</div>
      </div>`;
    }).join('');
    return {
      name: `leaders-${key}`,
      html: frame({
        colors: [lead.color, NAVY],
        meta: `${esc(season ?? '')} 정규시즌<br>${kstLabel(new Date())} 기준`,
        kicker: `LEADERS · ${en}`,
        title: `${label} TOP 5`,
        body: `<div class="panel"><div class="unit dim">경기당 평균</div>${rows}</div>`,
        css: `
.panel{justify-content:space-between;padding:28px 40px}
.unit{text-align:right;font-size:22px}
.row{display:flex;align-items:center;gap:24px;padding:18px 0;border-bottom:2px solid rgba(255,255,255,.12)}
.row:last-child{border-bottom:0}
.rk{width:60px;font-size:44px;font-weight:800;color:rgba(255,255,255,.7)}
.first .rk{color:${BRAND}}
.who{flex:1}
.pn{font-size:46px;font-weight:800}
.first .pn{font-size:54px}
.pt{margin-top:4px;font-size:24px;display:flex;align-items:center;gap:12px}
.pt .chip{width:10px;height:26px}
.v{font-size:64px;font-weight:800}
.first .v{font-size:84px}`,
      }),
    };
  });
}

// ---------------------------------------------------------------- 뉴스 브리핑

async function newsCards() {
  const [{ teams }, { articles }] = await Promise.all([getJson('kbl/teams'), getJson('news/kbl')]);
  const teamByLabel = Object.fromEntries(teams.map((t) => [`${t.city} ${t.shortName}`, t]));
  const ago = (iso) => {
    const h = Math.round((Date.now() - Date.parse(iso)) / 3600e3);
    return h < 1 ? '방금 전' : h < 24 ? `${h}시간 전` : `${Math.round(h / 24)}일 전`;
  };
  // 기사는 제목과 언론사만 쓴다(본문·사진은 쓰지 않는다).
  const top = articles.slice(0, 5);
  const rows = top.map((a) => {
    const t = teamByLabel[a.team];
    return `<div class="row">
      ${t ? `<div class="tag" style="background:${t.color}">${esc(short(t))}</div>` : '<div class="tag kbl">KBL</div>'}
      <div class="hl">${esc(a.title.replace(/\s*\.\.\.$/, '…'))}</div>
      <div class="src dim">${esc(a.source)} · ${ago(a.pub_date)}</div>
    </div>`;
  }).join('');
  return [{
    name: `news-${kstDay(new Date())}`,
    html: frame({
      colors: [BRAND, NAVY],
      meta: `KBL 뉴스<br>${kstLabel(new Date())}`,
      kicker: 'NEWS',
      title: '오늘의 KBL 뉴스',
      body: `<div class="panel">${rows}</div>`,
      css: `
.panel{justify-content:space-evenly;padding:16px 40px}
.row{padding:20px 0;border-bottom:2px solid rgba(255,255,255,.12)}
.row:last-child{border-bottom:0}
.tag{display:inline-block;padding:4px 14px;border-radius:8px;font-size:22px;font-weight:800}
.tag.kbl{background:${BRAND}}
.hl{margin-top:10px;font-size:36px;font-weight:800;line-height:1.3;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.src{margin-top:8px;font-size:22px}`,
    }),
  }];
}

// ----------------------------------------------------------------

const KINDS = { game: gameCards, today: todayCards, standings: standingsCards, leaders: leaderCards, news: newsCards };

async function main() {
  const [kind, arg] = process.argv.slice(2);
  const make = KINDS[kind];
  if (!make) {
    console.error(`사용: node tools/instagram/cards.js <${Object.keys(KINDS).join('|')}> [인자]`);
    process.exit(1);
  }
  const cards = await make(arg);
  if (!cards.length) return console.log('만들 카드가 없어요(오늘 경기 없음 등)');
  for (const f of await render(cards)) console.log(f);
}

if (require.main === module) {
  main().catch((e) => {
    console.error('실패:', e.message);
    process.exit(1);
  });
}

module.exports = { KINDS, render };
