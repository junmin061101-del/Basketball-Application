#!/usr/bin/env node
'use strict';

/**
 * 네이버 뉴스를 모아 정적 JSON으로 떨어뜨린다.
 *
 * GitHub Actions가 주기적으로 실행해 결과를 GitHub Pages에 올리고, 앱은 그
 * JSON만 읽는다. 이렇게 하면 Client ID/Secret이 앱에 들어가지 않으면서도
 * 유료 요금제(Cloud Functions)를 쓰지 않을 수 있다.
 *
 * 필요한 환경변수: NAVER_CLIENT_ID, NAVER_CLIENT_SECRET
 * 사용법: node tools/fetch-news.js <출력 디렉터리>
 */

const fs = require('fs/promises');
const path = require('path');

const {
  KBL_QUERIES,
  NBA_QUERIES,
  DEFAULT_OVERSEAS_QUERIES,
  naverHeaders,
  naverSearchUrl,
  naverErrorMessage,
  normalizeItem,
  mergeArticles,
  extractOgImage,
} = require('../functions/news-source');

/** 한 파일에 담는 최대 기사 수. */
const MAX_ARTICLES = 40;
/** 검색어 하나당 가져올 기사 수(네이버 display). */
const PER_QUERY = 20;
/** 정렬: date=최신순. */
const SORT = 'date';

/**
 * 이전 실행 결과. 이미 썸네일을 확인한 기사는 다시 긁지 않는다.
 * (Cloud Functions 버전의 Firestore 캐시를 대신하는 역할)
 */
const PREVIOUS_BASE = process.env.NEWS_PREVIOUS_BASE_URL ?? '';

const CREDENTIALS = {
  clientId: process.env.NAVER_CLIENT_ID,
  clientSecret: process.env.NAVER_CLIENT_SECRET,
};

function requireCredentials() {
  const missing = [
    CREDENTIALS.clientId ? null : 'NAVER_CLIENT_ID',
    CREDENTIALS.clientSecret ? null : 'NAVER_CLIENT_SECRET',
  ].filter(Boolean);
  if (missing.length > 0) {
    // 값은 절대 출력하지 않는다.
    console.error(`환경변수가 없습니다: ${missing.join(', ')}`);
    process.exit(1);
  }
}

/** 네이버 뉴스 검색 한 번 (NAVER API HUB). */
async function searchNaver(query) {
  const url = naverSearchUrl(query, { display: PER_QUERY, sort: SORT });
  const res = await fetch(url, {
    headers: naverHeaders(CREDENTIALS),
    signal: AbortSignal.timeout(15000),
  });
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    throw new Error(`HTTP ${res.status} ${naverErrorMessage(detail)}`);
  }
  const body = await res.json();
  return Array.isArray(body.items) ? body.items : [];
}

/**
 * 검색어 목록을 순서대로 돈다.
 *
 * 네이버 초당 호출 제한에 걸리지 않도록 한 건씩 처리하고, 한 검색어가
 * 실패해도 나머지는 살린다. 전부 실패하면 호출하는 쪽에서 판단하도록
 * 실패 수를 함께 돌려준다.
 */
async function collect(queries, category) {
  const lists = [];
  let failures = 0;
  for (const query of queries) {
    try {
      const items = await searchNaver(query);
      lists.push(items.map((item) => normalizeItem(item, category)).filter(Boolean));
    } catch (error) {
      failures += 1;
      console.warn(`  검색 실패 [${query}]: ${error.message}`);
    }
  }
  return { lists, failures, total: queries.length };
}

/** 지난 실행에서 이미 알아낸 썸네일을 가져온다. 실패해도 그냥 넘어간다. */
async function loadPreviousThumbnails() {
  const known = new Map();
  if (!PREVIOUS_BASE) return known;
  for (const name of ['all', 'kbl', 'overseas', 'nba']) {
    try {
      const res = await fetch(`${PREVIOUS_BASE}/${name}.json`, {
        signal: AbortSignal.timeout(10000),
      });
      if (!res.ok) continue;
      const body = await res.json();
      for (const article of body.articles ?? []) {
        // null도 기록해 둔다. 썸네일이 없던 기사를 매번 다시 긁지 않기 위해서.
        if (!known.has(article.article_url)) {
          known.set(article.article_url, article.thumbnail_url ?? null);
        }
      }
    } catch (_) {
      // 첫 실행이면 이전 결과가 없다. 정상이다.
    }
  }
  console.log(`이전 썸네일 ${known.size}건 재사용`);
  return known;
}

/** 기사 본문에서 og:image를 읽어 채운다. 한 건 실패는 무시한다. */
async function attachThumbnails(articles, known) {
  await Promise.all(
    articles.map(async (article) => {
      if (known.has(article.article_url)) {
        article.thumbnail_url = known.get(article.article_url);
        return;
      }
      try {
        const res = await fetch(article.article_url, {
          headers: {
            // UA가 없으면 og 태그를 안 주는 언론사가 있다.
            'User-Agent':
              'Mozilla/5.0 (compatible; BasketItBot/1.0; +https://basket-it-kbl.web.app)',
          },
          signal: AbortSignal.timeout(8000),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const html = (await res.text()).slice(0, 200000);
        article.thumbnail_url = extractOgImage(html, article.article_url);
      } catch (_) {
        article.thumbnail_url = null; // 썸네일 없이도 카드는 그려진다
      }
      known.set(article.article_url, article.thumbnail_url);
    }),
  );
  return articles;
}

async function main() {
  const outDir = process.argv[2];
  if (!outDir) {
    console.error('사용법: node tools/fetch-news.js <출력 디렉터리>');
    process.exit(1);
  }
  requireCredentials();

  console.log('KBL 기사 수집...');
  const kbl = await collect(KBL_QUERIES, 'kbl');
  console.log(`  검색어 ${kbl.total}개 중 ${kbl.total - kbl.failures}개 성공`);

  console.log('해외파 기사 수집...');
  const overseas = await collect(DEFAULT_OVERSEAS_QUERIES, 'overseas');
  console.log(`  검색어 ${overseas.total}개 중 ${overseas.total - overseas.failures}개 성공`);

  console.log('NBA 기사 수집...');
  const nba = await collect(NBA_QUERIES, 'nba');
  console.log(`  검색어 ${nba.total}개 중 ${nba.total - nba.failures}개 성공`);

  // 전부 실패했다면 자격증명이나 네이버 쪽 문제다. 이때 빈 파일을 내보내면
  // 멀쩡하던 뉴스가 사라지므로, 아무것도 쓰지 않고 실패로 끝낸다.
  if (kbl.failures === kbl.total && overseas.failures === overseas.total) {
    console.error('모든 검색이 실패했습니다. 기존 뉴스를 지우지 않기 위해 중단합니다.');
    process.exit(1);
  }

  const known = await loadPreviousThumbnails();

  const groups = {
    // 홈 화면은 KBL / NBA 두 섹션뿐이다. KBL 섹션에 해외파 한국 선수 소식도
    // 함께 보여주므로 kbl.json에 합쳐 둔다.
    kbl: mergeArticles([...kbl.lists, ...overseas.lists]).slice(0, MAX_ARTICLES),
    // 해외파 탭이 있던 예전 앱 버전이 아직 이 파일을 읽는다.
    overseas: mergeArticles(overseas.lists).slice(0, MAX_ARTICLES),
    nba: mergeArticles(nba.lists).slice(0, MAX_ARTICLES),
    all: mergeArticles([...kbl.lists, ...overseas.lists, ...nba.lists]).slice(
      0,
      MAX_ARTICLES,
    ),
  };

  console.log('썸네일 확인...');
  for (const articles of Object.values(groups)) {
    await attachThumbnails(articles, known);
  }

  await fs.mkdir(outDir, { recursive: true });
  const generatedAt = new Date().toISOString();
  for (const [category, articles] of Object.entries(groups)) {
    const file = path.join(outDir, `${category}.json`);
    await fs.writeFile(
      file,
      JSON.stringify({ category, generated_at: generatedAt, articles }, null, 0),
    );
    console.log(`${file}: ${articles.length}건`);
  }
}

main().catch((error) => {
  console.error('수집 실패:', error.message);
  process.exit(1);
});
