'use strict';

const test = require('node:test');
const assert = require('node:assert');

const {
  stripHtml,
  sourceNameFor,
  matchTeam,
  looksLikeBasketball,
  classifyLeague,
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

test('제목의 구단명과 리그 이름도 농구 신호로 본다', () => {
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

test('기사 내용으로 KBL / NBA를 가르고, 둘 다 아닌 주제는 버린다', () => {
  // 실제로 NBA 피드에 섞였던 KBL 감독 인터뷰
  assert.equal(classifyLeague('BTS에 감명받은 조상현 감독 LG만의 농구', '창원 LG 조상현 감독이'), 'kbl');
  assert.equal(classifyLeague('2027~28시즌 NBA 샐러리캡 전망 상향', ''), 'nba');
  assert.equal(classifyLeague('프로농구 소노, 청소년 장학금 후원', ''), 'kbl');
  // 국가대표·여자농구·해외파·다른 리그는 어느 리그에도 넣지 않는다
  assert.equal(classifyLeague("'아시안게임' 남자농구, 일본과 격돌", 'NBA 출신 선수도'), null);
  assert.equal(classifyLeague('"당신은 WNBA 스타" 방송인 발언', ''), null);
  assert.equal(classifyLeague('펄펄 나는 이현중', ''), null);
  assert.equal(classifyLeague('이현중, B리그 나가사키 데뷔', 'KBL 출신'), null);
  // 제목에 신호가 없으면 본문을 보되, 본문에 두 리그가 다 나오면 버린다
  assert.equal(classifyLeague('레알 마드리드, 닉 스미스 주니어 영입', 'NBA 샬럿 출신'), 'nba');
  assert.equal(classifyLeague('깜짝 얼리 엔트리 선언', 'KBL 신인 드래프트에'), 'kbl');
  assert.equal(classifyLeague('신인 드래프트 전망', 'KBL과 NBA 모두'), null);
});

test('아시안게임 약칭 AG는 붙여 써도 잡고, 영어 단어 속 AG는 넘긴다', () => {
  assert.equal(classifyLeague("[나고야AG] '일본 킬러' 한국, 일본 잡고 3전승", '창원 LG 이정현'), null);
  assert.equal(classifyLeague('[나고야 NOW] "韓 농구 역사상 가장 좋은 멤버"', '창원 LG'), null);
  assert.equal(classifyLeague('KBL, BAGEL과 스폰서 계약', ''), 'kbl');
  // KBL 구단의 일본 전지훈련 기사는 그대로 KBL
  assert.equal(classifyLeague('[나고야로 간 BASKETKOREA] 한국가스공사 선수들', ''), 'kbl');
});

test('매체만 다르고 제목이 같은 기사는 한 건만 남긴다', () => {
  const a = normalizeItem(item({ originallink: 'https://www.yna.co.kr/1' }), 'kbl');
  const b = normalizeItem(item({ originallink: 'https://www.newsis.com/2' }), 'kbl');
  const other = normalizeItem(item({ title: '서울 SK 다른 기사', originallink: 'https://www.newsis.com/3' }), 'kbl');
  const merged = mergeArticles([[a, b, other]]);
  assert.equal(merged.length, 2);
  assert.deepEqual(merged.map((x) => x.title).sort(), ['서울 SK 다른 기사', '서울 SK, 창원 LG 꺾고 4연승']);
});

test('KBL 구단 이름 속 NBA 구단 이름에 속지 않는다', () => {
  // 삼성 썬더스의 "썬더"는 오클라호마시티 썬더가 아니다
  assert.equal(classifyLeague('서울 삼성 썬더스, 새 외국인 선수 영입', ''), 'kbl');
  assert.equal(classifyLeague('서울 삼성, 썬더스 새 유니폼 공개', ''), 'kbl');
  assert.equal(classifyLeague('오클라호마시티 썬더, 2연승', ''), 'nba');
  // "커리어"는 스테판 커리가 아니다
  assert.equal(classifyLeague('하워드, 조지아 리그행… 해외리그 커리어', ''), null);
});

test('검색한 리그와 기사 리그가 다르면 그 피드에서 뺀다', () => {
  const kblInterview = item({
    title: 'BTS에 감명받은 조상현 감독 LG만의 농구',
    description: '창원 LG 조상현 감독이 필리핀 전지훈련에서',
    originallink: 'https://www.isplus.com/n/7',
    link: '',
  });
  assert.equal(normalizeItem(kblInterview, 'nba'), null);
  assert.equal(normalizeItem(kblInterview, 'kbl').category, 'kbl');
});

test('원문 URL로 중복을 지우고 최신순으로 정렬한다', () => {
  const older = normalizeItem(
    item({ originallink: 'https://basketkorea.com/n/9', pubDate: 'Sun, 07 Sep 2026 10:00:00 +0900' }),
    'kbl',
  );
  const newer = normalizeItem(item(), 'kbl');
  const duplicate = normalizeItem(item({ title: '서울 SK 같은 기사 다른 제목' }), 'kbl');

  const merged = mergeArticles([[older, newer], [duplicate]]);
  assert.equal(merged.length, 2);
  assert.equal(merged[0].article_url, 'https://jumpball.co.kr/news/1');
  assert.equal(merged[1].article_url, 'https://basketkorea.com/n/9');
});

test('중복이면 팀이 붙은 쪽을 남긴다', () => {
  const withTeam = normalizeItem(item(), 'kbl');
  const withoutTeam = normalizeItem(
    item({ title: '농구 4연승 소식', description: '프로농구 경기 리포트' }),
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
