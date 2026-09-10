'use strict';

/**
 * NBA 데이터를 한국어로 옮기는 사전.
 *
 * ESPN은 이름·팀·국가·대학을 전부 영어로 준다. 네이버 스포츠처럼 한국어로
 * 보여주기 위해 수집 단계에서 바꿔 내려보낸다. 앱은 번역을 모른다.
 *
 * 선수 이름은 tools/nba-player-names-ko.json(ESPN id → [영문, 한글])이
 * 기준이다. 사전에 없는 선수(새로 계약한 선수 등)는 Wikidata의 한국어
 * 표제어로 채우고, 거기에도 없으면 영문 그대로 둔다. 지어낸 음역을 쓰지
 * 않는다. 수집 로그에 빠진 선수가 찍히므로 사전에 추가하면 된다.
 */

const fs = require('fs');
const path = require('path');

/** ESPN 팀 id → [도시, 팀명, 짧은 이름]. 짧은 이름은 네이버 스포츠 표기를 따른다. */
const TEAM_KO = {
  1: ['애틀랜타', '호크스', '애틀랜타'],
  2: ['보스턴', '셀틱스', '보스턴'],
  17: ['브루클린', '네츠', '브루클린'],
  30: ['샬럿', '호네츠', '샬럿'],
  4: ['시카고', '불스', '시카고'],
  5: ['클리블랜드', '캐벌리어스', '클리블랜드'],
  6: ['댈러스', '매버릭스', '댈러스'],
  7: ['덴버', '너기츠', '덴버'],
  8: ['디트로이트', '피스톤스', '디트로이트'],
  9: ['골든스테이트', '워리어스', '골든스테이트'],
  10: ['휴스턴', '로키츠', '휴스턴'],
  11: ['인디애나', '페이서스', '인디애나'],
  12: ['LA', '클리퍼스', 'LA 클리퍼스'],
  13: ['LA', '레이커스', 'LA 레이커스'],
  29: ['멤피스', '그리즐리스', '멤피스'],
  14: ['마이애미', '히트', '마이애미'],
  15: ['밀워키', '벅스', '밀워키'],
  16: ['미네소타', '팀버울브스', '미네소타'],
  3: ['뉴올리언스', '펠리컨스', '뉴올리언스'],
  18: ['뉴욕', '닉스', '뉴욕'],
  25: ['오클라호마시티', '썬더', '오클라호마시티'],
  19: ['올랜도', '매직', '올랜도'],
  20: ['필라델피아', '세븐티식서스', '필라델피아'],
  21: ['피닉스', '선즈', '피닉스'],
  22: ['포틀랜드', '트레일블레이저스', '포틀랜드'],
  23: ['새크라멘토', '킹스', '새크라멘토'],
  24: ['샌안토니오', '스퍼스', '샌안토니오'],
  28: ['토론토', '랩터스', '토론토'],
  26: ['유타', '재즈', '유타'],
  27: ['워싱턴', '위저즈', '워싱턴'],
};

/** ESPN 국가 표기 → 한국어. 없는 나라는 영문 그대로 둔다. */
const COUNTRY_KO = {
  USA: '미국',
  'United States': '미국',
  Canada: '캐나다',
  Australia: '호주',
  Senegal: '세네갈',
  Bahamas: '바하마',
  Estonia: '에스토니아',
  Portugal: '포르투갈',
  England: '잉글랜드',
  'United Kingdom': '영국',
  'Great Britain': '영국',
  Scotland: '스코틀랜드',
  Wales: '웨일스',
  Ireland: '아일랜드',
  Russia: '러시아',
  France: '프랑스',
  Germany: '독일',
  Netherlands: '네덜란드',
  Croatia: '크로아티아',
  Spain: '스페인',
  'Bosnia & Herzegovina': '보스니아 헤르체고비나',
  'Bosnia and Herzegovina': '보스니아 헤르체고비나',
  Guinea: '기니',
  Serbia: '세르비아',
  Nigeria: '나이지리아',
  'Dominican Republic': '도미니카 공화국',
  Latvia: '라트비아',
  Brazil: '브라질',
  'New Zealand': '뉴질랜드',
  Switzerland: '스위스',
  Türkiye: '튀르키예',
  Turkey: '튀르키예',
  Cameroon: '카메룬',
  Japan: '일본',
  Slovenia: '슬로베니아',
  Georgia: '조지아',
  Mexico: '멕시코',
  Greece: '그리스',
  Italy: '이탈리아',
  Sweden: '스웨덴',
  Jamaica: '자메이카',
  Lithuania: '리투아니아',
  'Trinidad & Tobago': '트리니다드 토바고',
  'Trinidad and Tobago': '트리니다드 토바고',
  'Democratic Republic of Congo': '콩고민주공화국',
  'Democratic Republic of the Congo': '콩고민주공화국',
  Congo: '콩고',
  Belgium: '벨기에',
  'South Sudan': '남수단',
  Sudan: '수단',
  Israel: '이스라엘',
  'Czech Republic': '체코',
  Czechia: '체코',
  Austria: '오스트리아',
  Finland: '핀란드',
  Ukraine: '우크라이나',
  Haiti: '하이티',
  Uzbekistan: '우즈베키스탄',
  Nicaragua: '니카라과',
  Mali: '말리',
  Montenegro: '몬테네그로',
  China: '중국',
  'South Korea': '대한민국',
  Korea: '대한민국',
  Philippines: '필리핀',
  Taiwan: '대만',
  Argentina: '아르헨티나',
  'Puerto Rico': '푸에르토리코',
  Venezuela: '베네수엘라',
  Colombia: '콜롬비아',
  Uruguay: '우루과이',
  Cuba: '쿠바',
  Panama: '파나마',
  Poland: '폴란드',
  Hungary: '헝가리',
  Romania: '루마니아',
  Bulgaria: '불가리아',
  Slovakia: '슬로바키아',
  'North Macedonia': '북마케도니아',
  Denmark: '덴마크',
  Norway: '노르웨이',
  Iceland: '아이슬란드',
  Luxembourg: '룩셈부르크',
  Belarus: '벨라루스',
  Kazakhstan: '카자흐스탄',
  Angola: '앙골라',
  Ghana: '가나',
  Egypt: '이집트',
  'Ivory Coast': '코트디부아르',
  "Cote d'Ivoire": '코트디부아르',
  Gabon: '가봉',
  Chad: '차드',
  'Central African Republic': '중앙아프리카공화국',
  Tanzania: '탄자니아',
  Kenya: '케냐',
  Uganda: '우간다',
  Rwanda: '르완다',
  Ethiopia: '에티오피아',
  'South Africa': '남아프리카공화국',
  Morocco: '모로코',
  Tunisia: '튀니지',
  Algeria: '알제리',
  Lebanon: '레바논',
  Iran: '이란',
  Jordan: '요르단',
  Qatar: '카타르',
  India: '인도',
  Belize: '벨리즈',
  'St. Lucia': '세인트루시아',
  'US Virgin Islands': '미국령 버진아일랜드',
  'U.S. Virgin Islands': '미국령 버진아일랜드',
};

/** ESPN 대학 표기 → 한국어. 없는 학교는 영문 그대로 둔다. */
const COLLEGE_KO = {
  Akron: '애크런대',
  Alabama: '앨라배마대',
  'App State': '애팔래치안주립대',
  Arizona: '애리조나대',
  'Arizona State': '애리조나주립대',
  Arkansas: '아칸소대',
  Auburn: '오번대',
  BYU: '브리검영대',
  Baylor: '베일러대',
  Belmont: '벨몬트대',
  'Boston College': '보스턴칼리지',
  'Bowling Green': '볼링그린주립대',
  Bradley: '브래들리대',
  Buffalo: '버펄로대',
  Butler: '버틀러대',
  California: 'UC 버클리',
  Charleston: '찰스턴대',
  Cincinnati: '신시내티대',
  Clemson: '클렘슨대',
  'Cleveland State': '클리블랜드주립대',
  Colorado: '콜로라도대',
  'Colorado State': '콜로라도주립대',
  Creighton: '크레이턴대',
  Davidson: '데이비드슨대',
  Dayton: '데이턴대',
  DePaul: '드폴대',
  Drexel: '드렉셀대',
  Duke: '듀크대',
  Florida: '플로리다대',
  'Florida State': '플로리다주립대',
  'Fresno State': '프레즈노주립대',
  Furman: '퍼먼대',
  'George Washington': '조지워싱턴대',
  Georgetown: '조지타운대',
  Georgia: '조지아대',
  'Georgia Tech': '조지아공대',
  Gonzaga: '곤자가대',
  'Grand Canyon': '그랜드캐니언대',
  Harvard: '하버드대',
  'High Point': '하이포인트대',
  Houston: '휴스턴대',
  Illinois: '일리노이대',
  Indiana: '인디애나대',
  Iowa: '아이오와대',
  'Iowa State': '아이오와주립대',
  Kansas: '캔자스대',
  'Kansas State': '캔자스주립대',
  'Kent State': '켄트주립대',
  Kentucky: '켄터키대',
  LSU: '루이지애나주립대',
  Lehigh: '리하이대',
  Liberty: '리버티대',
  'Little Rock': '아칸소대 리틀록',
  'Long Beach State': '롱비치주립대',
  'Louisiana Tech': '루이지애나공대',
  Louisville: '루이빌대',
  'Loyola Chicago': '로욜라 시카고대',
  'Loyola Maryland': '로욜라 메릴랜드대',
  Marquette: '마케트대',
  Marshall: '마셜대',
  Maryland: '메릴랜드대',
  Memphis: '멤피스대',
  Miami: '마이애미대',
  Michigan: '미시간대',
  'Michigan State': '미시간주립대',
  Minnesota: '미네소타대',
  'Mississippi State': '미시시피주립대',
  Missouri: '미주리대',
  'Missouri State': '미주리주립대',
  'Morehead State': '모어헤드주립대',
  'Murray State': '머리주립대',
  'NC State': '노스캐롤라이나주립대',
  Nebraska: '네브래스카대',
  Nevada: '네바다대',
  'New Mexico': '뉴멕시코대',
  'New Mexico State': '뉴멕시코주립대',
  'North Carolina': '노스캐롤라이나대',
  'Northern Iowa': '노던아이오와대',
  Northwestern: '노스웨스턴대',
  'Notre Dame': '노터데임대',
  Oakland: '오클랜드대',
  Ohio: '오하이오대',
  'Ohio State': '오하이오주립대',
  Oklahoma: '오클라호마대',
  'Oklahoma State': '오클라호마주립대',
  'Ole Miss': '미시시피대',
  Oregon: '오리건대',
  'Oregon State': '오리건주립대',
  'Penn State': '펜실베이니아주립대',
  Pittsburgh: '피츠버그대',
  Princeton: '프린스턴대',
  Providence: '프로비던스대',
  Purdue: '퍼듀대',
  'Purdue Fort Wayne': '퍼듀대 포트웨인',
  Radford: '래드퍼드대',
  'Rhode Island': '로드아일랜드대',
  Rutgers: '럿거스대',
  SMU: '서던메소디스트대',
  "Saint Joseph's": '세인트조지프스대',
  'Saint Louis': '세인트루이스대',
  "Saint Mary's": '세인트메리스대',
  Samford: '샘퍼드대',
  'San Diego State': '샌디에이고주립대',
  'San Francisco': '샌프란시스코대',
  'Santa Clara': '샌타클래라대',
  'Seton Hall': '시턴홀대',
  'South Carolina': '사우스캐롤라이나대',
  'South Florida': '사우스플로리다대',
  "St. John's": '세인트존스대',
  Stanford: '스탠퍼드대',
  Syracuse: '시러큐스대',
  TCU: '텍사스크리스천대',
  Temple: '템플대',
  Tennessee: '테네시대',
  Texas: '텍사스대',
  'Texas A&M': '텍사스 A&M대',
  'Texas Tech': '텍사스공대',
  Toledo: '털리도대',
  Tulane: '툴레인대',
  UAB: '앨라배마대 버밍엄',
  'UC Santa Barbara': 'UC 샌타바버라',
  UCF: '센트럴플로리다대',
  UCLA: 'UCLA',
  UConn: '코네티컷대',
  UMass: '매사추세츠대',
  UNLV: '네바다대 라스베이거스',
  USC: '서던캘리포니아대',
  Utah: '유타대',
  'Utah State': '유타주립대',
  VCU: '버지니아커먼웰스대',
  Vanderbilt: '밴더빌트대',
  Vermont: '버몬트대',
  Villanova: '빌라노바대',
  Virginia: '버지니아대',
  'Virginia Tech': '버지니아공대',
  Wagner: '와그너대',
  'Wake Forest': '웨이크포레스트대',
  Washington: '워싱턴대',
  'Washington State': '워싱턴주립대',
  'Weber State': '웨버주립대',
  'West Virginia': '웨스트버지니아대',
  'Western Kentucky': '웨스턴켄터키대',
  'Wheeling Jesuit': '휠링제수이트대',
  'Wichita State': '위치토주립대',
  Wisconsin: '위스콘신대',
  Wofford: '워퍼드대',
  Wyoming: '와이오밍대',
  Xavier: '제이비어대',
  Yale: '예일대',
};

const NAMES_FILE = path.join(__dirname, 'nba-player-names-ko.json');

/** ESPN id → 한국어 이름. */
function loadPlayerNames(file = NAMES_FILE) {
  const raw = JSON.parse(fs.readFileSync(file, 'utf8'));
  return new Map(Object.entries(raw).map(([id, [, ko]]) => [id, ko]));
}

/** 사전에 있으면 한국어, 없으면 원래 값. 이미 한국어인 값은 그대로 지나간다. */
function translate(dict, value) {
  if (value == null) return value;
  return Object.prototype.hasOwnProperty.call(dict, value) ? dict[value] : value;
}

const countryKo = (value) => translate(COUNTRY_KO, value);
const collegeKo = (value) => translate(COLLEGE_KO, value);

/**
 * 팀을 한국어로. 영문 원래 값은 En 필드로 남긴다(사다리 기사의 팀명을
 * 맞춰볼 때와 디버깅에 쓴다). 약어도 따로 둔다.
 */
function localizeTeam(team) {
  const ko = TEAM_KO[team.id];
  if (!ko) return { ...team, cityEn: team.city, nameEn: team.name, abbreviation: team.shortName };
  const [city, name, short] = ko;
  return {
    ...team,
    city,
    name,
    shortName: short,
    cityEn: team.city,
    nameEn: team.name,
    abbreviation: team.shortName,
  };
}

/**
 * 선수 한 명을 제자리에서 한국어로 바꾼다.
 *
 * [names]는 사전, [fallbackNames]는 Wikidata에서 받은 이름. 둘 다 없으면
 * 영문 이름을 그대로 둔다. 반환값은 어떤 출처를 썼는지('dict' | 'wikidata' | null).
 */
function localizePlayer(player, names, fallbackNames = new Map()) {
  const english = player.nameEn ?? player.name;
  player.nameEn = english;
  let source = null;
  if (names.has(player.id)) {
    player.name = names.get(player.id);
    source = 'dict';
  } else if (fallbackNames.has(player.id)) {
    player.name = fallbackNames.get(player.id);
    source = 'wikidata';
  } else {
    player.name = english;
  }
  if ('college' in player) player.college = collegeKo(player.college);
  if ('birthCountry' in player) player.birthCountry = countryKo(player.birthCountry);
  if ('citizenship' in player) player.citizenship = countryKo(player.citizenship);
  return source;
}

const WIKIDATA_SPARQL = 'https://query.wikidata.org/sparql';

/**
 * 사전에 없는 선수의 한국어 이름을 Wikidata에서 찾는다. P3685가 ESPN NBA
 * 선수 id다. Wikidata는 연락처가 담긴 User-Agent를 요구해 그렇게 보낸다.
 * 실패하면 빈 Map(영문 이름 그대로 가게 된다).
 */
async function fetchWikidataKoreanNames(ids, { fetchImpl = fetch } = {}) {
  const valid = ids.filter((id) => /^\d+$/.test(id));
  if (valid.length === 0) return new Map();
  const query = `SELECT ?espn ?ko WHERE {
    VALUES ?espn { ${valid.map((id) => `"${id}"`).join(' ')} }
    ?p wdt:P3685 ?espn .
    ?p rdfs:label ?ko FILTER(LANG(?ko) = "ko")
  }`;
  try {
    const res = await fetchImpl(WIKIDATA_SPARQL, {
      method: 'POST',
      headers: {
        Accept: 'application/sparql-results+json',
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'BasketIt-collector/1.0 (https://github.com/junmin061101-del/Basketball-Application)',
      },
      body: new URLSearchParams({ query }).toString(),
      signal: AbortSignal.timeout(20000),
    });
    if (!res.ok) return new Map();
    const body = await res.json();
    const found = new Map();
    for (const row of body.results?.bindings ?? []) {
      const id = row.espn?.value;
      const ko = row.ko?.value;
      if (id && ko && !found.has(id)) found.set(id, ko);
    }
    return found;
  } catch (_) {
    return new Map();
  }
}

module.exports = {
  COLLEGE_KO,
  COUNTRY_KO,
  TEAM_KO,
  collegeKo,
  countryKo,
  fetchWikidataKoreanNames,
  loadPlayerNames,
  localizePlayer,
  localizeTeam,
};
