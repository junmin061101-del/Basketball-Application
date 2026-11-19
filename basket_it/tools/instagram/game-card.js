#!/usr/bin/env node
'use strict';

/**
 * 인스타그램용 KBL 경기 결과 카드(1080×1350 PNG)를 만든다.
 *
 * 우리가 모은 데이터(GitHub Pages의 경기·박스스코어·순위)로만 만든다. 팀 로고와
 * 선수 사진은 사용 허가 전이라 쓰지 않고 팀색으로 구분한다. HTML로 그리고
 * Playwright(Chromium)로 찍는다. 글꼴은 앱과 같은 Pretendard(assets/fonts).
 *
 * 사용: node tools/instagram/game-card.js [경기 id] [출력 폴더]
 *       경기 id를 빼면 가장 최근에 끝난 경기.
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const DATA = 'https://junmin061101-del.github.io/Basketball-Application/kbl';
const FONTS = path.join(__dirname, '..', '..', 'assets', 'fonts');
const WEEKDAYS = ['일', '월', '화', '수', '목', '금', '토'];
/** 긴 구단 이름은 팬들이 부르는 이름으로(앱의 team_label.dart와 같다). */
const SHORT = { 한국가스공사: '페가수스', 현대모비스: '모비스' };

const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const getJson = (p) => fetch(`${DATA}/${p}.json`).then((r) => {
  if (!r.ok) throw new Error(`${p}.json HTTP ${r.status}`);
  return r.json();
});

/** 팀색이 밝으면 검은 글자. */
function onColor(hex) {
  const n = parseInt(hex.replace('#', ''), 16);
  const [r, g, b] = [n >> 16, (n >> 8) & 255, n & 255];
  return 0.299 * r + 0.587 * g + 0.114 * b > 170 ? '#111827' : '#FFFFFF';
}

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

/**
 * 배경 시안. CARD_THEME=light|split|brand (없으면 짙은 남색).
 * split은 두 팀 색을 대각선으로 나눈다(앱의 경기 날 카드와 같은 느낌).
 */
const THEMES = {
  light: `body{background:#F8FAFC;color:#0F172A}.side{background:#FFFFFF;box-shadow:0 8px 30px rgba(15,23,42,.08)}
    .meta,.lbl,.stats div,.foot{color:#64748B}.line{color:#475569}.line b,.stats b,.foot b{color:#0F172A}
    .score.lose{color:#CBD5E1}.top{border-top-color:#E2E8F0}`,
  brand: `body{background:linear-gradient(160deg,#F97316 0%,#EA580C 55%,#9A3412 100%)}.final{color:#FFEDD5}
    .meta,.foot{color:#FFEDD5}.logo{background:#fff}.logo svg{stroke:#F97316}.side{background:rgba(255,255,255,.12)}
    .tag{background:#fff;color:#EA580C}.score.lose{color:rgba(255,255,255,.45)}.top{border-top-color:rgba(255,255,255,.2)}
    .lbl,.stats div{color:#FED7AA}`,
};

function cardHtml({ game, home, away, homeTop, awayTop, rankOf, homeTotals, awayTotals }) {
  const d = new Date(game.startTime);
  const kst = new Date(d.getTime() + 9 * 3600e3);
  const date = `${kst.getUTCMonth() + 1}.${kst.getUTCDate()} (${WEEKDAYS[kst.getUTCDay()]})`;
  const homeWon = game.homeScore > game.awayScore;
  const font = (w, file) =>
    `@font-face{font-family:P;font-weight:${w};src:url("file://${path.join(FONTS, file)}")}`;

  const side = (team, score, won, top, rank, totals) => `
    <div class="side" style="--c:${team.color};--on:${onColor(team.color)}">
      <div class="band">
        <div class="city">${esc(team.city)}</div>
        <div class="name">${esc(SHORT[team.shortName] ?? team.shortName)}</div>
        ${rank ? `<div class="rec">${rank.rank}위 · ${rank.wins}승 ${rank.losses}패</div>` : ''}
      </div>
      <div class="score ${won ? 'win' : 'lose'}">${score}</div>
      ${won ? '<div class="tag">WIN</div>' : '<div class="tag ghost">&nbsp;</div>'}
      ${totals ? `<div class="stats">${totals.map(([k, v]) => `<div><span>${k}</span><b>${v}</b></div>`).join('')}</div>` : ''}
      ${top ? `
      <div class="top">
        <div class="lbl">최다 득점</div>
        <div class="pname">${esc(top.name)}</div>
        <div class="line"><b>${top.points}</b>점 <b>${top.oreb + top.dreb}</b>리바 <b>${top.ast}</b>어시</div>
      </div>` : ''}
    </div>`;

  return `<!doctype html><html><head><meta charset="utf-8"><style>
${font(400, 'Pretendard-Regular.otf')}${font(600, 'Pretendard-SemiBold.otf')}${font(700, 'Pretendard-Bold.otf')}${font(800, 'Pretendard-ExtraBold.otf')}
*{box-sizing:border-box;margin:0}
body{width:1080px;height:1350px;font-family:P,sans-serif;background:#0F172A;color:#fff;display:flex;flex-direction:column;padding:64px 60px 56px}
.head{display:flex;align-items:center;justify-content:space-between}
.brand{display:flex;align-items:center;gap:16px;font-size:40px;font-weight:800}
.logo{width:64px;height:64px;border-radius:16px;background:#F97316;display:flex;align-items:center;justify-content:center}
.meta{text-align:right;font-size:28px;font-weight:600;color:#94A3B8;line-height:1.35}
.final{margin-top:56px;font-size:30px;font-weight:800;letter-spacing:6px;color:#F97316}
.title{margin-top:8px;font-size:64px;font-weight:800;letter-spacing:-1px}
.board{margin-top:44px;display:flex;gap:28px;flex:1}
.side{flex:1;background:#1E293B;border-radius:32px;overflow:hidden;display:flex;flex-direction:column;align-items:center}
.band{width:100%;background:var(--c);color:var(--on);padding:30px 24px 26px;text-align:center}
.city{font-size:28px;font-weight:600;opacity:.85}
.name{font-size:56px;font-weight:800;line-height:1.15;letter-spacing:-1px}
.rec{margin-top:6px;font-size:24px;font-weight:600;opacity:.85}
.score{margin-top:34px;font-size:168px;font-weight:800;line-height:1;letter-spacing:-4px;font-variant-numeric:tabular-nums}
.score.lose{color:#64748B}
.tag{margin-top:14px;padding:6px 20px;border-radius:999px;background:#F97316;font-size:24px;font-weight:800;letter-spacing:3px}
.tag.ghost{background:transparent}
.stats{margin-top:30px;width:100%;padding:0 40px;display:grid;grid-template-columns:1fr 1fr;gap:14px 24px}
.stats div{display:flex;justify-content:space-between;align-items:baseline;font-size:26px;color:#94A3B8}
.stats b{font-size:32px;font-weight:800;color:#fff;font-variant-numeric:tabular-nums}
.top{margin-top:auto;width:100%;padding:28px 24px 34px;border-top:2px solid #334155;text-align:center}
.lbl{font-size:24px;font-weight:600;color:#94A3B8}
.pname{margin-top:6px;font-size:44px;font-weight:800}
.line{margin-top:6px;font-size:28px;color:#CBD5E1}
.line b{color:#fff;font-weight:800;font-size:34px}
.foot{margin-top:40px;display:flex;justify-content:space-between;align-items:center;font-size:26px;color:#94A3B8}
.foot b{color:#fff}
${THEMES[process.env.CARD_THEME] ?? ''}
${process.env.CARD_THEME === 'split' ? `body{background:linear-gradient(135deg,${home.color} 0%,${home.color} 50%,${away.color} 50%,${away.color} 100%)}
  .side{background:rgba(15,23,42,.78)}.band{background:transparent;color:#fff}.final{color:#fff}
  .meta,.foot{color:rgba(255,255,255,.85)}` : ''}
</style></head><body>
  <div class="head">
    <div class="brand"><div class="logo"><svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 2v20M2 12h20M5 5c3 3 3 11 0 14M19 5c-3 3-3 11 0 14"/></svg></div>Baskit</div>
    <div class="meta">KBL 정규시즌<br>${date}</div>
  </div>
  <div class="final">FINAL</div>
  <div class="title">${esc(SHORT[home.shortName] ?? home.shortName)} ${game.homeScore} : ${game.awayScore} ${esc(SHORT[away.shortName] ?? away.shortName)}</div>
  <div class="board">
    ${side(home, game.homeScore, homeWon, homeTop, rankOf[home.id], homeTotals)}
    ${side(away, game.awayScore, !homeWon, awayTop, rankOf[away.id], awayTotals)}
  </div>
  <div class="foot"><span>홈 ${esc(SHORT[home.shortName] ?? home.shortName)} · 원정 ${esc(SHORT[away.shortName] ?? away.shortName)}</span><span>실시간 기록은 <b>Baskit</b> · basket-it-kbl.web.app</span></div>
</body></html>`;
}

async function main() {
  const [wantId, outDir = path.join(__dirname, '..', '..', 'build', 'cards')] = process.argv.slice(2);
  const [{ games }, { teams }, standings] = await Promise.all([getJson('games'), getJson('teams'), getJson('standings')]);
  const finished = games.filter((g) => g.status === 'finished').sort((a, b) => a.startTime.localeCompare(b.startTime));
  const game = wantId ? games.find((g) => g.id === wantId) : finished.at(-1);
  if (!game) throw new Error('경기를 찾지 못했어요');
  const box = await getJson(`boxscores/${game.id}`).catch(() => ({ lines: [] }));
  const teamById = Object.fromEntries(teams.map((t) => [t.id, t]));
  const rows = (standings.standings ?? standings.rows ?? []).slice().sort((a, b) => b.wins / (b.wins + b.losses || 1) - a.wins / (a.wins + a.losses || 1));
  const rankOf = Object.fromEntries(rows.map((s, i) => [s.teamId, { rank: i + 1, wins: s.wins, losses: s.losses }]));

  const html = cardHtml({
    game,
    home: teamById[game.homeTeamId],
    away: teamById[game.awayTeamId],
    homeTop: topPlayer(box.lines, game.homeTeamId),
    awayTop: topPlayer(box.lines, game.awayTeamId),
    homeTotals: teamTotals(box.lines, game.homeTeamId),
    awayTotals: teamTotals(box.lines, game.awayTeamId),
    rankOf,
  });

  fs.mkdirSync(outDir, { recursive: true });
  const htmlFile = path.join(outDir, `${game.id}.html`);
  fs.writeFileSync(htmlFile, html);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1080, height: 1350 } });
  await page.goto(`file://${htmlFile}`);
  await page.evaluate(() => document.fonts.ready);
  const png = path.join(outDir, `${game.id}${process.env.CARD_THEME ? `-${process.env.CARD_THEME}` : ''}.png`);
  await page.screenshot({ path: png });
  await browser.close();
  console.log(png);
}

main().catch((e) => {
  console.error('실패:', e.message);
  process.exit(1);
});
