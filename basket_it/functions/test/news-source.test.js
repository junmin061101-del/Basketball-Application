'use strict';

const test = require('node:test');
const assert = require('node:assert');

const {
  stripHtml,
  sourceNameFor,
  matchTeam,
  looksLikeBasketball,
  normalizeItem,
  mergeArticles,
  extractOgImage,
} = require('../news-source');

const item = (over = {}) => ({
  title: '서울 <b>SK</b>, 창원 LG 꺾고 4연승',
  description: '&quot;농구&quot; 리바운드를 장악했다',
  originallink: 'https://jumpball.co.kr/news/1',
  link: 'https://n.news.naver.com/article/1',
  pubDate: 'Mon, 08 Sep 2026 10:00:00 +0900',
  ...over,
});

test('HTML 태그와 엔티티를 벗긴다', () => {
  assert.equal(stripHtml('<b>KBL</b> &amp; &quot;농구&quot;'), 'KBL & "농구"');
  assert.equal(stripHtml(undefined), '');
});

test('화이트리스트 매체만 통과하고 서브도메인도 인정한다', () => {
  assert.equal(sourceNameFor('https://www.jumpball.co.kr/n/1'), '점프볼');
  assert.equal(sourceNameFor('https://sports.chosun.com/n/1'), '스포츠조선');
  assert.equal(sourceNameFor('https://unknown-blog.com/1'), null);
  assert.equal(sourceNameFor('not a url'), null);
});

test('구단 키워드로 팀을 붙인다', () => {
  assert.deepEqual(matchTeam('안양 정관장 5연승'), { id: 'kgc', label: '안양 정관장' });
  assert.equal(matchTeam('오늘 날씨'), null);
});

test('originallink을 우선 쓰고 태그를 벗겨 정규화한다', () => {
  const article = normalizeItem(item(), 'kbl');
  assert.equal(article.article_url, 'https://jumpball.co.kr/news/1');
  assert.equal(article.title, '서울 SK, 창원 LG 꺾고 4연승');
  assert.equal(article.description, '"농구" 리바운드를 장악했다');
  assert.equal(article.source, '점프볼');
  assert.equal(article.team, '서울 SK');
  assert.equal(article.team_id, 'sk');
  assert.equal(article.pub_date, '2026-09-08T01:00:00.000Z');
});

test('originallink이 없으면 link로 넘어간다', () => {
  const article = normalizeItem(
    item({ originallink: '', link: 'https://basketkorea.com/n/2' }),
    'kbl',
  );
  assert.equal(article.article_url, 'https://basketkorea.com/n/2');
});

test('화이트리스트 밖 매체와 깨진 날짜는 버린다', () => {
  assert.equal(normalizeItem(item({ originallink: 'https://spam.example/1', link: '' }), 'kbl'), null);
  assert.equal(normalizeItem(item({ pubDate: '어제' }), 'kbl'), null);
});

test('일반 매체는 제목에 농구 신호가 있어야 통과한다', () => {
  // 본문에 농구가 스쳐 지나가도 제목이 정치 기사면 버린다.
  // (실제로 "NBA 농구장에서 열린 전당대회" 기사가 피드에 섞여 들어왔다)
  assert.equal(
    looksLikeBasketball('[美공화 전대]막 올랐지만 좌석 텅텅…축제 분위기 실종', '뉴시스'),
    false,
  );
  assert.equal(
    looksLikeBasketball('유토파이 스튜디오, AI 접목 영화·TV 콘텐츠 제작 확대', '경향신문'),
    false,
  );
  assert.equal(looksLikeBasketball('KBL, 라건아 선수 등록 정상 진행', '동아일보'), true);
  assert.equal(looksLikeBasketball("'완전체' 농구 대표팀 완성", '스포츠서울'), true);
});

test('제목의 구단명과 해외파 선수 이름도 농구 신호로 본다', () => {
  assert.equal(looksLikeBasketball('안양 정관장, 5연승으로 단독 선두', '스포츠조선'), true);
  assert.equal(looksLikeBasketball('이현중, G리그 데뷔전 18득점', 'SBS'), true);
  assert.equal(looksLikeBasketball('오늘 개막식 열려', 'SBS'), false);
});

test('농구 전문지 기사는 제목이 밋밋해도 받아준다', () => {
  // "달라노 반튼, 산둥과 계약" 같은 이적 기사에는 농구 단어가 없다.
  assert.equal(looksLikeBasketball('달라노 반튼, 중국으로 향한다… 산둥과 계약', '루키'), true);
  assert.equal(looksLikeBasketball('달라노 반튼, 중국으로 향한다… 산둥과 계약', '뉴시스'), false);
});

test('본문에만 농구가 스쳐도 일반 매체 기사는 버린다', () => {
  const politics = normalizeItem(
    item({
      title: '개막 3시간 지나도 텅텅 빈 객석',
      description: '미 프로농구 댈러스 매버릭스가 홈구장으로 쓰는 경기장은...',
      originallink: 'https://www.chosun.com/x/1',
      link: '',
    }),
    'kbl',
  );
  assert.equal(politics, null);
});

test('해외파 기사는 team이 해외파로 표시된다', () => {
  const article = normalizeItem(
    item({ title: '이현중 G리그 농구 데뷔', originallink: 'https://rookie.co.kr/n/3' }),
    'overseas',
  );
  assert.equal(article.category, 'overseas');
  assert.equal(article.team, '해외파');
});

test('원문 URL로 중복을 지우고 최신순으로 정렬한다', () => {
  const older = normalizeItem(
    item({ originallink: 'https://basketkorea.com/n/9', pubDate: 'Sun, 07 Sep 2026 10:00:00 +0900' }),
    'kbl',
  );
  const newer = normalizeItem(item(), 'kbl');
  const duplicate = normalizeItem(item({ title: '농구 같은 기사 다른 제목' }), 'kbl');

  const merged = mergeArticles([[older, newer], [duplicate]]);
  assert.equal(merged.length, 2);
  assert.equal(merged[0].article_url, 'https://jumpball.co.kr/news/1');
  assert.equal(merged[1].article_url, 'https://basketkorea.com/n/9');
});

test('중복이면 팀이 붙은 쪽을 남긴다', () => {
  const withTeam = normalizeItem(item(), 'kbl');
  const withoutTeam = normalizeItem(
    item({ title: '농구 4연승 소식', description: '경기 리포트' }),
    'kbl',
  );
  assert.equal(withoutTeam.team_id, null);
  const merged = mergeArticles([[withoutTeam], [withTeam]]);
  assert.equal(merged[0].team_id, 'sk');
});

test('og:image를 절대 주소로 만들어 준다', () => {
  assert.equal(
    extractOgImage('<meta property="og:image" content="/img/a.jpg">', 'https://jumpball.co.kr/n/1'),
    'https://jumpball.co.kr/img/a.jpg',
  );
  assert.equal(
    extractOgImage('<meta name="twitter:image" content="https://cdn.x/b.jpg">', 'https://jumpball.co.kr/n/1'),
    'https://cdn.x/b.jpg',
  );
  assert.equal(extractOgImage('<html></html>', 'https://jumpball.co.kr/n/1'), null);
});

test('NBA 기사는 구단을 붙이고 제목을 본문보다 우선한다', () => {
  const nba = normalizeItem(
    item({
      title: "'목표는 우승' 미네소타의 에드워즈, 한 걸음씩",
      description: '지난 시즌 덴버에게 밀린 미네소타는...',
      originallink: 'https://www.basketkorea.com/n/5',
      link: '',
    }),
    'nba',
  );
  // 본문에 먼저 나오는 덴버가 아니라 제목의 미네소타가 붙어야 한다.
  assert.equal(nba.team, '미네소타 팀버울브스');
  assert.equal(nba.team_id, '16');
  assert.equal(nba.category, 'nba');
});

test('제목에 구단이 없으면 본문에서 찾는다', () => {
  const nba = normalizeItem(
    item({
      title: 'NBA 은퇴 선수, 1조원 잭팟',
      description: '클리블랜드 캐벌리어스 출신으로...',
      originallink: 'https://www.rookie.co.kr/n/6',
      link: '',
    }),
    'nba',
  );
  assert.equal(nba.team_id, '5');
});

test('NBA 구단명이 제목에 있으면 일반 매체 기사도 농구로 본다', () => {
  assert.equal(looksLikeBasketball('레이커스, 필 잭슨 감독 동상 공개', '동아일보'), true);
  assert.equal(looksLikeBasketball('오늘의 증시 마감', '동아일보'), false);
});
