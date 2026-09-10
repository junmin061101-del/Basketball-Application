'use strict';

/**
 * Basket it 뉴스 백엔드.
 *
 * 네이버 뉴스 검색 API로 KBL·해외파 농구 기사를 모아 앱이 바로 그릴 수 있는
 * 형태로 돌려준다. 응답은 Firestore에 캐시해 두어, 같은 카테고리로 자주
 * 요청이 와도 네이버 API 호출량이 늘지 않도록 한다.
 *
 * 자격증명은 코드에 두지 않고 환경변수로만 읽는다. 값은 functions/.env에
 * 두며(.gitignore 처리됨), firebase deploy 시 CLI가 함수 환경변수로 넣어준다.
 *   NAVER_CLIENT_ID     = NAVER API HUB의 Client ID (X-NCP-APIGW-API-KEY-ID)
 *   NAVER_CLIENT_SECRET = 같은 곳의 Client Secret (X-NCP-APIGW-API-KEY)
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const {
  KBL_QUERIES,
  DEFAULT_OVERSEAS_QUERIES,
  naverHeaders,
  naverSearchUrl,
  naverErrorMessage,
  normalizeItem,
  mergeArticles,
  extractOgImage,
} = require('./news-source');

admin.initializeApp();
const db = admin.firestore();

/** 캐시 유지 시간(초). 이보다 최근에 모은 결과가 있으면 그대로 준다. */
const CACHE_TTL_SECONDS = 300;
/** 한 응답에 담는 최대 기사 수. */
const MAX_ARTICLES = 40;
/** 검색어 하나당 가져올 기사 수(display). 네이버 허용 범위는 1~100. */
const PER_QUERY = 20;
/** 정렬 기본값. date=최신순, sim=정확도순. */
const DEFAULT_SORT = 'date';
const ALLOWED_SORTS = ['date', 'sim'];

const NEWS_CACHE = 'newsCache';
const IMAGE_CACHE = 'newsImageCache';

/**
 * 네이버 뉴스 검색 한 번 (NAVER API HUB).
 *
 * 검색어 하나가 실패해도 나머지는 살려야 하므로 빈 배열로 돌려준다.
 */
async function searchNaver(query, credentials, options = {}) {
  const url = naverSearchUrl(query, {
    display: options.display ?? PER_QUERY,
    sort: ALLOWED_SORTS.includes(options.sort) ? options.sort : DEFAULT_SORT,
  });

  try {
    const res = await fetch(url, {
      headers: naverHeaders(credentials),
      signal: AbortSignal.timeout(10000),
    });
    if (!res.ok) {
      // 401이면 자격증명 문제다. 값은 절대 로그에 남기지 않는다.
      const detail = await res.text().catch(() => '');
      logger.warn('네이버 검색 실패', {
        query,
        status: res.status,
        detail: naverErrorMessage(detail),
      });
      return [];
    }
    const body = await res.json();
    return Array.isArray(body.items) ? body.items : [];
  } catch (error) {
    logger.warn('네이버 검색 예외', { query, message: error.message });
    return [];
  }
}

/** 검색어 목록을 돌며 정규화된 기사 배열을 만든다. */
async function collect(queries, category, credentials, options = {}) {
  const results = await Promise.all(
    queries.map((q) => searchNaver(q, credentials, options)),
  );
  return results.map((items) =>
    items.map((item) => normalizeItem(item, category)).filter(Boolean),
  );
}

/**
 * 기사 URL의 og:image를 읽어 썸네일을 채운다.
 *
 * 한 번 읽은 결과는 Firestore에 캐시하고(이미지가 없던 기사도 기록해 재요청을
 * 막는다), 기사마다 try/catch를 따로 걸어 한 건이 실패해도 나머지는 남는다.
 */
async function attachThumbnails(articles) {
  const targets = articles.slice(0, MAX_ARTICLES);
  const ids = targets.map((a) => imageCacheId(a.article_url));

  // 캐시를 먼저 한 번에 읽는다.
  const cached = new Map();
  if (ids.length > 0) {
    const refs = ids.map((id) => db.collection(IMAGE_CACHE).doc(id));
    const snaps = await db.getAll(...refs).catch((error) => {
      logger.warn('썸네일 캐시 읽기 실패', { message: error.message });
      return [];
    });
    for (const snap of snaps) {
      if (snap.exists) cached.set(snap.id, snap.get('thumbnail_url') ?? null);
    }
  }

  const writes = [];
  await Promise.all(
    targets.map(async (article, index) => {
      const id = ids[index];
      if (cached.has(id)) {
        article.thumbnail_url = cached.get(id);
        return;
      }
      try {
        const res = await fetch(article.article_url, {
          headers: {
            // 일부 언론사는 UA가 없으면 og 태그를 주지 않는다.
            'User-Agent':
              'Mozilla/5.0 (compatible; BasketItBot/1.0; +https://basket-it-kbl.web.app)',
          },
          signal: AbortSignal.timeout(5000),
        });
        if (!res.ok) throw new Error(`status ${res.status}`);
        // og 태그는 <head>에 있으므로 앞부분만 읽어도 충분하다.
        const html = (await res.text()).slice(0, 200000);
        article.thumbnail_url = extractOgImage(html, article.article_url);
      } catch (error) {
        // 한 건 실패는 조용히 넘긴다. 썸네일 없이도 카드가 그려진다.
        logger.debug('썸네일 추출 실패', {
          url: article.article_url,
          message: error.message,
        });
        article.thumbnail_url = null;
      }
      writes.push({ id, thumbnail_url: article.thumbnail_url });
    }),
  );

  if (writes.length > 0) {
    try {
      const batch = db.batch();
      for (const w of writes) {
        batch.set(db.collection(IMAGE_CACHE).doc(w.id), {
          thumbnail_url: w.thumbnail_url,
          cachedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (error) {
      logger.warn('썸네일 캐시 저장 실패', { message: error.message });
    }
  }

  return targets;
}

/** Firestore 문서 id로 쓸 수 있게 URL을 인코딩한다. */
function imageCacheId(url) {
  return Buffer.from(url).toString('base64url').slice(0, 300);
}

/** 운영 중 검색어를 바꿀 수 있도록 config/news 문서를 참고한다. */
async function loadQueryConfig() {
  try {
    const snap = await db.collection('config').doc('news').get();
    if (!snap.exists) return {};
    return snap.data() ?? {};
  } catch (error) {
    logger.warn('뉴스 설정 읽기 실패', { message: error.message });
    return {};
  }
}

/**
 * 실제 수집 본체. 캐시를 먼저 보고, 없으면 네이버를 호출한다.
 *
 * 정렬이 다르면 결과도 다르므로 캐시도 정렬별로 따로 둔다.
 */
async function fetchNews(
  category,
  credentials,
  { force = false, sort = DEFAULT_SORT } = {},
) {
  const cacheRef = db
    .collection(NEWS_CACHE)
    .doc(sort === DEFAULT_SORT ? category : `${category}_${sort}`);

  if (!force) {
    try {
      const snap = await cacheRef.get();
      if (snap.exists) {
        const cachedAt = snap.get('cachedAt');
        const ageSec = cachedAt
          ? (Date.now() - cachedAt.toDate().getTime()) / 1000
          : Infinity;
        if (ageSec < CACHE_TTL_SECONDS) {
          return { articles: snap.get('articles') ?? [], cached: true };
        }
      }
    } catch (error) {
      logger.warn('뉴스 캐시 읽기 실패', { message: error.message });
    }
  }

  const config = await loadQueryConfig();
  const kblQueries = config.kblQueries ?? KBL_QUERIES;
  const overseasQueries = config.overseasQueries ?? DEFAULT_OVERSEAS_QUERIES;

  const options = { sort };
  const lists = [];
  if (category === 'kbl' || category === 'all') {
    lists.push(...(await collect(kblQueries, 'kbl', credentials, options)));
  }
  if (category === 'overseas' || category === 'all') {
    lists.push(
      ...(await collect(overseasQueries, 'overseas', credentials, options)),
    );
  }

  const merged = mergeArticles(lists);
  const articles = await attachThumbnails(merged);

  try {
    await cacheRef.set({
      articles,
      cachedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.warn('뉴스 캐시 저장 실패', { message: error.message });
  }

  return { articles, cached: false };
}

/**
 * 네이버 API 자격증명을 환경변수에서 읽는다.
 *
 * 값 자체는 절대 로그에 남기지 않는다. 빠졌을 때만 어느 키가 없는지 알린다.
 */
function credentialsFrom() {
  const clientId = process.env.NAVER_CLIENT_ID;
  const clientSecret = process.env.NAVER_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    const missing = [
      clientId ? null : 'NAVER_CLIENT_ID',
      clientSecret ? null : 'NAVER_CLIENT_SECRET',
    ].filter(Boolean);
    logger.error('네이버 API 자격증명 누락', { missing });
    throw new HttpsError(
      'failed-precondition',
      '네이버 API 자격증명이 설정되지 않았습니다.',
    );
  }
  return { clientId, clientSecret };
}

/**
 * 앱에서 호출하는 엔드포인트.
 *
 * 요청: { category: 'kbl' | 'overseas' | 'all' }
 * 응답: { category, articles: [{ category, team, source, pub_date, title,
 *         description, article_url, thumbnail_url }] }
 */
exports.getBasketballNews = onCall(
  {
    region: 'asia-northeast3',
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (request) => {
    const category = request.data?.category ?? 'all';
    if (!['kbl', 'overseas', 'all'].includes(category)) {
      throw new HttpsError(
        'invalid-argument',
        "category는 'kbl' | 'overseas' | 'all' 중 하나여야 합니다.",
      );
    }

    const sort = request.data?.sort ?? DEFAULT_SORT;
    if (!ALLOWED_SORTS.includes(sort)) {
      throw new HttpsError(
        'invalid-argument',
        "sort는 'date'(최신순) | 'sim'(정확도순) 중 하나여야 합니다.",
      );
    }

    const { articles, cached } = await fetchNews(category, credentialsFrom(), {
      sort,
    });
    logger.info('뉴스 응답', {
      category,
      sort,
      count: articles.length,
      cached,
    });
    return { category, sort, articles };
  },
);

/**
 * 10분마다 미리 수집해 캐시를 데워 둔다.
 * 앱이 폴링할 때 대부분 캐시로 응답돼 체감 속도가 빨라진다.
 */
exports.refreshBasketballNews = onSchedule(
  {
    schedule: 'every 10 minutes',
    region: 'asia-northeast3',
    timeZone: 'Asia/Seoul',
    timeoutSeconds: 300,
    memory: '512MiB',
  },
  async () => {
    const credentials = credentialsFrom();
    for (const category of ['all', 'kbl', 'overseas']) {
      try {
        const { articles } = await fetchNews(category, credentials, {
          force: true,
        });
        logger.info('뉴스 사전 수집 완료', {
          category,
          count: articles.length,
        });
      } catch (error) {
        logger.error('뉴스 사전 수집 실패', {
          category,
          message: error.message,
        });
      }
    }
  },
);
