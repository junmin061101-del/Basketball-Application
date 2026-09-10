/**
 * getBasketballNews 전체 파이프라인 검증.
 * 네이버 API 자격증명 없이도 확인할 수 있도록 fetch만 스텁으로 바꾼다.
 * Firestore는 실제 에뮬레이터를 쓴다(캐시 동작까지 확인).
 */
// emulators:exec가 넣어주는 값을 우선 쓰고, 직접 실행할 때만 기본값을 쓴다.
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
process.env.GCLOUD_PROJECT ??= 'demo-basket';
process.env.NAVER_CLIENT_ID = 'test-id';
process.env.NAVER_CLIENT_SECRET = 'test-secret';

const assert = require('node:assert');
const { getBasketballNews } = require('../index.js');

// 네이버가 실제로 주는 모양: <b> 강조, HTML 엔티티, originallink/link 분리
const NAVER_ITEMS = [
  {
    title: '서울 <b>SK</b>, 창원 LG 꺾고 4연승…&quot;리바운드가 승부처&quot;',
    originallink: 'https://jumpball.co.kr/news/articleView.html?idxno=1001',
    link: 'https://n.news.naver.com/mnews/article/065/0000001',
    description: '서울 <b>SK</b>가 농구 경기에서 리바운드를 장악하며 승리했다. &amp; 4쿼터 역전.',
    pubDate: 'Wed, 09 Sep 2026 21:30:00 +0900',
  },
  {
    title: '안양 정관장 5연승, 단독 선두 질주',
    originallink: '', // originallink이 빈 경우 link로 폴백해야 한다
    link: 'https://www.basketkorea.com/news/1002',
    description: '프로농구 안양 정관장이 5연승을 달렸다.',
    pubDate: 'Wed, 09 Sep 2026 20:10:00 +0900',
  },
  {
    title: '[속보] 아이돌 그룹 컴백 확정', // 제목에 농구 신호 없음 → 걸러져야 한다
    originallink: 'https://osen.co.kr/article/2001',
    link: '',
    description: '신곡 발표 예정.',
    pubDate: 'Wed, 09 Sep 2026 22:00:00 +0900',
  },
  {
    title: '개인 블로그가 정리한 KBL 농구 순위', // 화이트리스트 밖 매체 → 걸러져야 한다
    originallink: 'https://some-random-blog.tistory.com/3',
    link: '',
    description: 'KBL 농구 순위 정리',
    pubDate: 'Wed, 09 Sep 2026 22:30:00 +0900',
  },
  {
    title: '이현중, G리그 데뷔전 18득점 농구 인생 새 출발',
    originallink: 'https://rookie.co.kr/news/3001',
    link: '',
    description: '해외파 이현중이 첫 경기부터 존재감을 보였다.',
    pubDate: 'Wed, 09 Sep 2026 23:00:00 +0900',
  },
];

const OG_HTML = {
  'https://jumpball.co.kr/news/articleView.html?idxno=1001':
    '<html><head><meta property="og:image" content="/photo/1001.jpg"></head></html>',
  'https://www.basketkorea.com/news/1002':
    '<html><head><meta name="twitter:image" content="https://cdn.basketkorea.com/1002.jpg"></head></html>',
  // rookie 기사는 og 태그가 없다 → thumbnail_url이 null이어야 한다
  'https://rookie.co.kr/news/3001': '<html><head><title>기사</title></head></html>',
};

let naverCalls = 0;
let pageFetches = 0;
const seenParams = [];

globalThis.fetch = async (url, init) => {
  if (String(url).startsWith('https://naverapihub.apigw.ntruss.com/')) {
    naverCalls++;
    const u = new URL(url);
    seenParams.push({
      query: u.searchParams.get('query'),
      display: u.searchParams.get('display'),
      sort: u.searchParams.get('sort'),
      id: init.headers['X-NCP-APIGW-API-KEY-ID'],
      secret: init.headers['X-NCP-APIGW-API-KEY'],
    });
    return {
      ok: true,
      status: 200,
      json: async () => ({ items: NAVER_ITEMS }),
      text: async () => '',
    };
  }
  pageFetches++;
  const html = OG_HTML[String(url)];
  if (html === undefined) {
    // 썸네일 못 읽는 기사 하나는 일부러 실패시켜, 나머지가 살아남는지 본다
    throw new Error('simulated network failure');
  }
  return { ok: true, status: 200, text: async () => html };
};

const call = (data) =>
  getBasketballNews.run({ data, auth: null, rawRequest: { headers: {} } });

(async () => {
  // --- 1. kbl 카테고리 ---
  const kbl = await call({ category: 'kbl' });
  console.log('네이버 호출 횟수:', naverCalls, '(검색어 수만큼)');
  console.log('기사 페이지 fetch 횟수:', pageFetches);
  console.log('응답 키:', Object.keys(kbl));
  console.log('sort:', kbl.sort, '| category:', kbl.category);
  console.log('기사 수:', kbl.articles.length);
  console.log('\n--- 기사 ---');
  for (const a of kbl.articles) {
    console.log(JSON.stringify(a, null, 1));
  }

  // 헤더에 자격증명이 실려 나갔는지
  assert.equal(seenParams[0].id, 'test-id');
  assert.equal(seenParams[0].secret, 'test-secret');
  assert.equal(seenParams[0].display, '20');
  assert.equal(seenParams[0].sort, 'date');
  console.log('\n[OK] 헤더/파라미터 전달 확인, 인코딩된 query 예:', seenParams[2].query);

  const byUrl = Object.fromEntries(kbl.articles.map((a) => [a.article_url, a]));

  // HTML 태그·엔티티 제거
  const sk = byUrl['https://jumpball.co.kr/news/articleView.html?idxno=1001'];
  assert.equal(sk.title, '서울 SK, 창원 LG 꺾고 4연승…"리바운드가 승부처"');
  assert.ok(!sk.description.includes('<b>') && sk.description.includes('&') === true);
  console.log('[OK] <b> 태그와 HTML 엔티티 제거');

  // 팀 매칭
  assert.equal(sk.team, '서울 SK');
  assert.equal(sk.team_id, 'sk');
  console.log('[OK] 구단 키워드로 team/team_id 부여');

  // originallink 우선, 없으면 link 폴백
  assert.ok(byUrl['https://www.basketkorea.com/news/1002']);
  console.log('[OK] originallink이 비면 link로 폴백');

  // 화이트리스트 밖 / 농구 무관 기사 제거
  assert.ok(!byUrl['https://some-random-blog.tistory.com/3'], '블로그 매체가 통과됨');
  assert.ok(!byUrl['https://osen.co.kr/article/2001'], '농구 무관 기사가 통과됨');
  console.log('[OK] 화이트리스트 밖 매체·농구 무관 기사 제거');

  // og:image → thumbnail_url (상대경로는 절대경로로)
  assert.equal(sk.thumbnail_url, 'https://jumpball.co.kr/photo/1001.jpg');
  assert.equal(
    byUrl['https://www.basketkorea.com/news/1002'].thumbnail_url,
    'https://cdn.basketkorea.com/1002.jpg',
  );
  console.log('[OK] og:image / twitter:image → thumbnail_url (상대경로 보정)');

  // 썸네일 실패한 기사도 살아남았는지
  const rookie = byUrl['https://rookie.co.kr/news/3001'];
  assert.ok(rookie, '썸네일 없는 기사가 사라짐');
  assert.equal(rookie.thumbnail_url, null);
  console.log('[OK] 썸네일 추출 실패해도 기사는 유지되고 null로 남는다');

  // 최신순 정렬
  const dates = kbl.articles.map((a) => a.pub_date);
  assert.deepEqual([...dates].sort().reverse(), dates);
  console.log('[OK] pub_date 최신순 정렬');

  // --- 2. 캐시 ---
  const before = naverCalls;
  await call({ category: 'kbl' });
  assert.equal(naverCalls, before, '캐시를 안 쓰고 다시 호출함');
  console.log('[OK] 5분 캐시 적중 → 네이버 재호출 없음');

  // --- 3. 썸네일 캐시 ---
  const pagesBefore = pageFetches;
  await call({ category: 'all' }); // 다른 캐시 문서 → 네이버는 다시 부르지만 이미지는 캐시
  assert.ok(pageFetches - pagesBefore < 3, '이미지 캐시가 동작하지 않음');
  console.log('[OK] 기사별 og:image 캐시 적중 (추가 페이지 fetch', pageFetches - pagesBefore, '건)');

  // --- 4. overseas ---
  const ov = await call({ category: 'overseas', sort: 'sim' });
  assert.equal(ov.sort, 'sim');
  assert.equal(seenParams[seenParams.length - 1].sort, 'sim');
  assert.ok(ov.articles.every((a) => a.category === 'overseas' && a.team === '해외파'));
  console.log('[OK] overseas 카테고리 + sort=sim 반영, team="해외파"');

  // --- 5. 잘못된 인자 ---
  for (const bad of [{ category: 'nba' }, { category: 'kbl', sort: 'oldest' }]) {
    await assert.rejects(() => call(bad), /invalid-argument|중 하나/);
  }
  console.log('[OK] 잘못된 category/sort는 invalid-argument로 거부');

  console.log('\n전체 파이프라인 검증 통과');
})().catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
