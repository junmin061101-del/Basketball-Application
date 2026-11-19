#!/usr/bin/env node
'use strict';

/**
 * 오늘의 농구 헤드라인 카드뉴스(표지 + KBL 1장 + NBA 1장)를 만든다.
 *
 *   node tools/instagram/headlines.js            Claude가 요약을 쓴다(ANTHROPIC_API_KEY 필요)
 *   node tools/instagram/headlines.js --dry-run  요약 자리에 시험 문장(카드 모양 확인용)
 *
 * 기사는 우리 수집기가 네이버 검색 API로 모은 것(GitHub Pages의 news/kbl·nba.json)만
 * 쓴다. 리그마다 "가장 많은 언론사가 다룬 소식"을 헤드라인으로 고른다. Claude는 그
 * 소식을 다룬 기사들의 제목과 미리보기 문장만 보고 우리 말투로 2~3문장 요약을 쓴다.
 * 기사 본문·사진은 가져오지 않는다. 원문 링크는 캡션 파일에 모은다.
 */

const fs = require('fs');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk').default;
const { betaZodOutputFormat } = require('@anthropic-ai/sdk/helpers/beta/zod');
const { z } = require('zod');
const { frame, render, getJson, esc, short, kstLabel, kstDay, BRAND, NAVY } = require('./cards');

const OUT = path.join(__dirname, '..', '..', 'build', 'cards');
const DAY_MS = 24 * 3600e3;

// ---------------------------------------------------------------- 헤드라인 고르기

/** 제목의 두 글자 이상 낱말(따옴표·기호 제외). */
const words = (title) =>
  new Set(String(title).replace(/\[[^\]]*\]/g, ' ').match(/[가-힣A-Za-z0-9]{2,}/g) ?? []);

/** 두 제목이 같은 소식인지: 고유 낱말이 둘 이상 겹치면 같다고 본다. */
function sameStory(a, b) {
  let shared = 0;
  for (const w of a) if (b.has(w)) shared++;
  return shared >= 2;
}

/**
 * 최근 24시간 기사 중 가장 많은 언론사가 다룬 소식. 같으면 더 최근 것.
 * 반환: 그 소식을 다룬 기사들(최신순). 기사가 없으면 [].
 */
function topStory(articles, now = Date.now()) {
  const recent = articles.filter((a) => now - Date.parse(a.pub_date) < DAY_MS);
  const pool = recent.length ? recent : articles.slice(0, 10);
  const tagged = pool.map((a) => ({ a, w: words(a.title) }));
  let best = [];
  for (const { a, w } of tagged) {
    const cluster = tagged.filter((t) => sameStory(w, t.w)).map((t) => t.a);
    const sources = new Set(cluster.map((c) => c.source)).size;
    const bestSources = new Set(best.map((c) => c.source)).size;
    if (sources > bestSources || (sources === bestSources && Date.parse(a.pub_date) > Date.parse(best[0]?.pub_date ?? 0))) {
      best = cluster;
    }
  }
  return best.sort((x, y) => Date.parse(y.pub_date) - Date.parse(x.pub_date));
}

// ---------------------------------------------------------------- 요약 쓰기

const Summary = z.object({
  headline: z.string().describe('카드 제목. 22자 이내, 기사 제목을 그대로 베끼지 말고 새로 쓴다'),
  summary: z.string().describe('2~3문장 요약. 해요체. 기사에 나온 사실만'),
});

const SYSTEM = `너는 농구 앱 Baskit의 인스타그램 카드뉴스 편집자야.
같은 소식을 다룬 여러 기사의 제목과 미리보기 문장을 받으면, 카드에 넣을 제목과 요약을 써.
- 요약은 2~3문장, 친근한 해요체. 숫자·이름·팀처럼 기사에 나온 사실만 쓰고, 나오지 않은 내용은 추측하지 않아.
- 기사 문장을 그대로 옮기지 말고 우리 말로 다시 써. 큰따옴표 인용은 짧은 한마디만.
- 선수와 팀 이름은 기사에 나온 표기 그대로 써.
- 제목은 22자 이내로, 소식의 핵심이 한눈에 보이게.`;

async function summarize(client, league, story) {
  const material = story
    .slice(0, 6)
    .map((a, i) => `${i + 1}. [${a.source}] ${a.title}\n   ${a.description ?? ''}`)
    .join('\n');
  const response = await client.beta.messages.parse({
    model: 'claude-opus-5-5',
    max_tokens: 16000,
    betas: ['server-side-fallback-2026-07-01'],
    fallbacks: 'default',
    output_config: { effort: 'medium', format: betaZodOutputFormat(Summary) },
    system: SYSTEM,
    messages: [{ role: 'user', content: `${league} 소식이야.\n\n${material}` }],
  });
  if (response.stop_reason === 'refusal') throw new Error(`${league}: 요약 거절(${response.stop_details?.category ?? '-'})`);
  if (!response.parsed_output) throw new Error(`${league}: 요약 형식이 맞지 않음`);
  return response.parsed_output;
}

const dryRun = (league, story) => ({
  headline: `[시험] ${story[0].title.slice(0, 18)}`,
  summary: `${league} 시험 문장이에요. 실제로는 Claude가 이 소식을 다룬 기사 ${story.length}개의 제목과 미리보기를 보고 2~3문장으로 요약해요.`,
});

// ---------------------------------------------------------------- 카드

function storyCard({ league, item, story, team, index }) {
  const sources = [...new Set(story.map((a) => a.source))];
  const credit = sources.length > 1 ? `${sources[0]} 외 ${sources.length - 1}곳` : sources[0];
  const color = team?.color ?? (league === 'NBA' ? '#1D428A' : BRAND);
  return {
    name: `headline-${index}-${league.toLowerCase()}`,
    html: frame({
      colors: [color, NAVY],
      meta: `오늘의 헤드라인<br>${kstLabel(new Date())}`,
      kicker: `${league} HEADLINE`,
      title: '',
      body: `<div class="panel">
        ${team ? `<div class="tag" style="background:${team.color}">${esc(team.city)} ${esc(short(team))}</div>` : `<div class="tag league">${league}</div>`}
        <div class="hl">${esc(item.headline)}</div>
        <div class="sum">${esc(item.summary)}</div>
        <div class="src">출처: ${esc(credit)} · 원문 링크는 캡션에</div>
      </div>`,
      css: `
.title{display:none}
.panel{margin-top:40px;padding:56px 56px 48px;justify-content:flex-start}
.tag{align-self:flex-start;padding:8px 18px;border-radius:10px;font-size:26px;font-weight:800}
.tag.league{background:${league === 'NBA' ? '#C9082A' : BRAND}}
.hl{margin-top:32px;font-size:68px;font-weight:800;line-height:1.25;letter-spacing:-1.5px}
.sum{margin-top:40px;font-size:38px;line-height:1.6;color:#F1F5F9;font-weight:600}
.src{margin-top:auto;font-size:24px;color:#CBD5E1}`,
    }),
  };
}

function coverCard(items) {
  const list = items.map((it) => `<div class="item"><span class="lg">${it.league}</span>${esc(it.item.headline)}</div>`).join('');
  return {
    name: 'headline-0-cover',
    html: frame({
      colors: [BRAND, NAVY],
      meta: `카드뉴스<br>${kstLabel(new Date())}`,
      kicker: 'TODAY\'S HEADLINES',
      title: '오늘의 농구<br>헤드라인',
      body: `<div class="panel">${list}<div class="swipe">옆으로 넘겨 보세요 →</div></div>`,
      css: `
.title{font-size:96px;line-height:1.15}
.panel{padding:40px 48px}
.item{display:flex;gap:20px;align-items:flex-start;padding:28px 0;border-bottom:2px solid rgba(255,255,255,.12);font-size:40px;font-weight:800;line-height:1.35}
.lg{flex:none;margin-top:6px;padding:4px 14px;border-radius:8px;background:${BRAND};font-size:24px}
.swipe{margin-top:auto;text-align:right;font-size:28px;color:#CBD5E1;font-weight:700}`,
    }),
  };
}

// ----------------------------------------------------------------

async function main() {
  const dry = process.argv.includes('--dry-run');
  const client = dry ? null : new Anthropic();
  const [{ teams }, kbl, nba] = await Promise.all([getJson('kbl/teams'), getJson('news/kbl'), getJson('news/nba')]);
  const teamOf = (label) => teams.find((t) => `${t.city} ${t.shortName}` === label);

  const items = [];
  for (const [league, feed] of [['KBL', kbl], ['NBA', nba]]) {
    const story = topStory(feed.articles ?? []);
    if (!story.length) continue;
    const item = dry ? dryRun(league, story) : await summarize(client, league, story);
    items.push({ league, item, story, team: league === 'KBL' ? teamOf(story[0].team) : null });
  }
  if (!items.length) return console.log('헤드라인으로 쓸 기사가 없어요');

  const cards = [coverCard(items), ...items.map((it, i) => storyCard({ ...it, index: i + 1 }))];
  for (const f of await render(cards)) console.log(f);

  // 캡션: 요약과 원문 링크(언론사 저작권을 지키고 원문으로 보낸다).
  const caption = [
    `🏀 오늘의 농구 헤드라인 (${kstLabel(new Date())})`,
    '',
    ...items.flatMap(({ league, item, story }) => [
      `[${league}] ${item.headline}`,
      ...[...new Map(story.map((a) => [a.source, a])).values()].slice(0, 3).map((a) => `- ${a.source}: ${a.article_url}`),
      '',
    ]),
    '실시간 경기·기록은 Baskit에서 👉 basket-it-kbl.web.app',
    '#KBL #NBA #농구 #프로농구 #바스킷 #Baskit',
  ].join('\n');
  const capFile = path.join(OUT, `headlines-${kstDay(new Date())}.txt`);
  fs.writeFileSync(capFile, caption);
  console.log(capFile);
}

if (require.main === module) {
  main().catch((e) => {
    if (e instanceof Anthropic.AuthenticationError) console.error('실패: ANTHROPIC_API_KEY가 없거나 틀렸어요');
    else if (e instanceof Anthropic.RateLimitError) console.error('실패: 요청이 너무 많아요. 잠시 후 다시');
    else if (e instanceof Anthropic.APIError) console.error(`실패: API 오류 ${e.status} ${e.message}`);
    else console.error('실패:', e.message);
    process.exit(1);
  });
}

module.exports = { topStory, sameStory, words };
