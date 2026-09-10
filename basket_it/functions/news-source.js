'use strict';

/**
 * 뉴스 수집에 쓰는 상수/순수 함수 모음.
 *
 * 네트워크를 타지 않는 로직만 모아 두어 단위 테스트가 쉽도록 분리했다.
 */

/**
 * 네이버 뉴스 검색 엔드포인트.
 *
 * 기존 openapi.naver.com/v1/search/news.json은 NAVER API HUB로 이관됐다.
 * 도메인·경로·인증 헤더가 모두 바뀌었고, 응답 필드(title, originallink,
 * link, description, pubDate)는 그대로다.
 */
const NAVER_NEWS_ENDPOINT =
  'https://naverapihub.apigw.ntruss.com/search/v1/news';

/** API HUB 인증 헤더. NCP API Gateway 방식이다. */
function naverHeaders({ clientId, clientSecret }) {
  return {
    'X-NCP-APIGW-API-KEY-ID': clientId,
    'X-NCP-APIGW-API-KEY': clientSecret,
  };
}

/**
 * 검색 URL을 만든다.
 *   query   검색어(URLSearchParams가 인코딩까지 처리)
 *   display 가져올 개수
 *   sort    date=최신순 / sim=정확도순
 */
function naverSearchUrl(query, { display = 20, sort = 'date' } = {}) {
  const params = new URLSearchParams({
    query,
    display: String(display),
    sort,
  });
  return `${NAVER_NEWS_ENDPOINT}?${params}`;
}

/**
 * 오류 응답에서 사람이 읽을 메시지를 뽑는다.
 *
 * API HUB는 `{"error":{"errorCode","message","details"}}` 형태로 답한다.
 * 구형 응답(`{"errorCode","errorMessage"}`)도 함께 받아준다.
 */
function naverErrorMessage(text) {
  try {
    const body = JSON.parse(text);
    if (body.error) {
      const { errorCode, message, details } = body.error;
      return [errorCode, message, details].filter(Boolean).join(' / ');
    }
    if (body.errorMessage) {
      return [body.errorCode, body.errorMessage].filter(Boolean).join(' / ');
    }
  } catch (_) {
    // JSON이 아니면 원문 앞부분을 그대로 쓴다.
  }
  return (text ?? '').slice(0, 200);
}

/**
 * 허용 매체 화이트리스트. 도메인 → 표시할 매체명.
 * 네이버 뉴스 검색은 블로그성·연예 매체까지 섞여 나오므로, 농구 기사를
 * 실제로 많이 내는 매체 위주로 넉넉히 열어 두고 운영하며 좁혀 간다.
 */
const SOURCE_BY_DOMAIN = {
  'jumpball.co.kr': '점프볼',
  'basketkorea.com': '바스켓코리아',
  'rookie.co.kr': '루키',
  'kbl.or.kr': 'KBL',
  'sports.chosun.com': '스포츠조선',
  'osen.co.kr': 'OSEN',
  'spotvnews.co.kr': 'SPOTV뉴스',
  'mksports.co.kr': 'MK스포츠',
  'sportsseoul.com': '스포츠서울',
  'sportsworldi.com': '스포츠월드',
  'xportsnews.com': '엑스포츠뉴스',
  'isplus.com': '일간스포츠',
  'star.mt.co.kr': '스타뉴스',
  'newsis.com': '뉴시스',
  'news1.kr': '뉴스1',
  'yna.co.kr': '연합뉴스',
  'yonhapnews.co.kr': '연합뉴스',
  'donga.com': '동아일보',
  'hankyung.com': '한국경제',
  'mk.co.kr': '매일경제',
  'khan.co.kr': '경향신문',
  'hani.co.kr': '한겨레',
  'segye.com': '세계일보',
  'edaily.co.kr': '이데일리',
  'sedaily.com': '서울경제',
  'chosun.com': '조선일보',
  'joongang.co.kr': '중앙일보',
  'jtbc.co.kr': 'JTBC',
  'sbs.co.kr': 'SBS',
  'kbs.co.kr': 'KBS',
  'imbc.com': 'MBC',
  'ytn.co.kr': 'YTN',
  'naeil.com': '내일신문',
  'sporbiz.co.kr': '한국스포츠경제',
  'sportalkorea.com': '스포탈코리아',
  'interfootball.co.kr': '인터풋볼',
  'thespike.co.kr': '더스파이크',
};

/**
 * KBL 10개 구단. 검색 키워드와 기사 → 팀 매칭에 함께 쓴다.
 * id는 앱의 Team.id와 같아야 팀 컬러/로고가 연결된다.
 */
const KBL_TEAMS = [
  { id: 'sk', label: '서울 SK', keywords: ['서울 SK', 'SK 나이츠', 'SK나이츠'] },
  { id: 'kgc', label: '안양 정관장', keywords: ['정관장', '안양 정관장', '레드부스터스'] },
  { id: 'db', label: '원주 DB', keywords: ['원주 DB', 'DB 프로미', 'DB프로미'] },
  { id: 'lg', label: '창원 LG', keywords: ['창원 LG', 'LG 세이커스', 'LG세이커스'] },
  { id: 'kcc', label: '부산 KCC', keywords: ['부산 KCC', 'KCC 이지스', 'KCC이지스'] },
  { id: 'kt', label: '수원 KT', keywords: ['수원 KT', 'KT 소닉붐', 'KT소닉붐'] },
  { id: 'kogas', label: '대구 한국가스공사', keywords: ['한국가스공사', '대구 한국가스공사', '페가수스'] },
  { id: 'sono', label: '고양 소노', keywords: ['고양 소노', '소노 스카이거너스', '소노스카이거너스'] },
  { id: 'mobis', label: '울산 현대모비스', keywords: ['현대모비스', '울산 현대모비스', '피버스'] },
  { id: 'samsung', label: '서울 삼성', keywords: ['서울 삼성', '삼성 썬더스', '삼성썬더스'] },
];

/** KBL 카테고리 검색어. 리그 일반 + 구단별. */
const KBL_QUERIES = ['KBL', '프로농구', ...KBL_TEAMS.map((t) => `${t.label} 농구`)];

/**
 * 해외파 검색어. 선수 명단은 시즌마다 바뀌므로 Firestore
 * `config/news` 문서의 overseasQueries 로 덮어쓸 수 있게 했다.
 */
const DEFAULT_OVERSEAS_QUERIES = [
  '한국 선수 NBA',
  '한국 농구 G리그',
  '해외파 농구 한국',
  '이현중 농구',
  '여준석 농구',
  '박지현 농구',
  '농구 유럽 리그 한국 선수',
  '한국 선수 B리그 농구',
];

/** 해외에서 뛰는 한국 선수. 제목에 이름만 있어도 농구 기사로 본다. */
const OVERSEAS_PLAYERS = ['이현중', '여준석', '박지현'];

/** 농구 기사임을 알려주는 단어들. */
const BASKETBALL_HINTS = [
  '농구', 'KBL', 'NBA', 'G리그', 'WKBL', '바스켓', '리바운드', '덩크',
  '3점슛', '자유투', '플레이오프',
];

/**
 * 농구만 다루는 매체. 이런 곳의 기사는 제목에 '농구'가 없어도
 * (예: "달라노 반튼, 산둥과 계약") 농구 기사가 맞다.
 */
const BASKETBALL_OUTLETS = new Set(['점프볼', '바스켓코리아', '루키', 'KBL']);

/** 제목에 이게 있으면 농구 기사로 인정한다. */
const TITLE_SIGNALS = [
  ...BASKETBALL_HINTS,
  ...OVERSEAS_PLAYERS,
  ...[], // 구단 키워드는 KBL_TEAMS에서 아래 looksLikeBasketball이 직접 본다
];

/** HTML 태그와 엔티티를 제거한다(네이버 응답의 <b> 강조 등). */
function stripHtml(value) {
  if (!value) return '';
  return value
    .replace(/<[^>]*>/g, '')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** URL에서 www.를 뗀 호스트를 돌려준다. 파싱 실패 시 null. */
function hostOf(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch (_) {
    return null;
  }
}

/**
 * 화이트리스트 매체명을 찾는다. 서브도메인(sports.chosun.com 등)도
 * 뒤에서부터 맞춰보기 때문에 등록 도메인 하나로 계열 매체를 함께 받는다.
 */
function sourceNameFor(url) {
  const host = hostOf(url);
  if (!host) return null;
  if (SOURCE_BY_DOMAIN[host]) return SOURCE_BY_DOMAIN[host];
  const parts = host.split('.');
  for (let i = 1; i < parts.length - 1; i += 1) {
    const candidate = parts.slice(i).join('.');
    if (SOURCE_BY_DOMAIN[candidate]) return SOURCE_BY_DOMAIN[candidate];
  }
  return null;
}

/** 제목/본문에서 구단 키워드를 찾아 팀을 붙인다. 없으면 null. */
function matchTeam(text) {
  if (!text) return null;
  for (const team of KBL_TEAMS) {
    if (team.keywords.some((k) => text.includes(k))) {
      return { id: team.id, label: team.label };
    }
  }
  return null;
}

/**
 * 농구 기사인지 판단한다.
 *
 * 본문까지 보면 "NBA 농구장으로 쓰이는 경기장에서 열린 전당대회" 같은
 * 스치는 언급만으로 정치·연예 기사가 들어온다. 그래서 일반 매체는
 * **제목**에 농구 신호가 있어야 통과시키고, 농구만 다루는 매체는
 * 제목이 밋밋해도(선수 이적 기사 등) 받아준다.
 */
function looksLikeBasketball(title, source) {
  if (BASKETBALL_OUTLETS.has(source)) return true;
  if (!title) return false;
  if (TITLE_SIGNALS.some((signal) => title.includes(signal))) return true;
  // 구단 이름이 제목에 있으면 농구 기사다.
  return KBL_TEAMS.some((team) => team.keywords.some((k) => title.includes(k)));
}

/**
 * 네이버 검색 결과 한 건을 앱이 쓰는 형태로 바꾼다.
 * 화이트리스트에 없거나 농구와 무관하면 null.
 */
function normalizeItem(item, category) {
  const articleUrl = item.originallink || item.link;
  if (!articleUrl) return null;

  const source = sourceNameFor(articleUrl);
  if (!source) return null; // 화이트리스트 밖 매체는 버린다

  const title = stripHtml(item.title);
  const description = stripHtml(item.description);
  if (!title) return null;
  if (!looksLikeBasketball(title, source)) return null;

  const pubDate = new Date(item.pubDate);
  if (Number.isNaN(pubDate.getTime())) return null;

  const team = category === 'kbl' ? matchTeam(`${title} ${description}`) : null;

  return {
    category,
    team: team ? team.label : category === 'overseas' ? '해외파' : null,
    team_id: team ? team.id : null,
    source,
    pub_date: pubDate.toISOString(),
    title,
    description,
    article_url: articleUrl,
    thumbnail_url: null,
  };
}

/** article_url 기준 중복 제거 후 최신순 정렬. */
function mergeArticles(lists) {
  const byUrl = new Map();
  for (const list of lists) {
    for (const article of list) {
      if (!article) continue;
      const existing = byUrl.get(article.article_url);
      // 같은 기사가 여러 검색어에서 나오면 팀이 붙은 쪽을 남긴다.
      if (!existing || (!existing.team_id && article.team_id)) {
        byUrl.set(article.article_url, article);
      }
    }
  }
  return [...byUrl.values()].sort(
    (a, b) => new Date(b.pub_date) - new Date(a.pub_date),
  );
}

/** HTML에서 og:image(없으면 twitter:image)를 뽑는다. */
function extractOgImage(html, baseUrl) {
  if (!html) return null;
  const patterns = [
    /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i,
    /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i,
    /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/i,
  ];
  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      try {
        return new URL(match[1], baseUrl).toString();
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}

module.exports = {
  OVERSEAS_PLAYERS,
  BASKETBALL_OUTLETS,
  NAVER_NEWS_ENDPOINT,
  naverHeaders,
  naverSearchUrl,
  naverErrorMessage,
  SOURCE_BY_DOMAIN,
  KBL_TEAMS,
  KBL_QUERIES,
  DEFAULT_OVERSEAS_QUERIES,
  stripHtml,
  hostOf,
  sourceNameFor,
  matchTeam,
  looksLikeBasketball,
  normalizeItem,
  mergeArticles,
  extractOgImage,
};
