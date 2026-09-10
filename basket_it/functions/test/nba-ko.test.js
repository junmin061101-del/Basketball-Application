'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  COUNTRY_KO,
  TEAM_KO,
  fetchWikidataKoreanNames,
  loadPlayerNames,
  localizePlayer,
  localizeTeam,
} = require('../../tools/nba-ko');
const { reboundSplit, seasonHigh } = require('../../tools/fetch-nba');

test('이름 사전: 모든 항목이 [영문, 한글] 형식이다', () => {
  const raw = require('../../tools/nba-player-names-ko.json');
  for (const [id, entry] of Object.entries(raw)) {
    assert.match(id, /^\d+$/, id);
    assert.equal(entry.length, 2, id);
    assert.match(entry[1], /[가-힣]/, `${id} ${entry[0]}`);
  }
  assert.equal(loadPlayerNames().get('5104157'), '빅터 웸반야마');
});

test('30개 팀 모두 한국어 이름이 있다', () => {
  assert.equal(Object.keys(TEAM_KO).length, 30);
  const lal = localizeTeam({ id: '13', city: 'Los Angeles', name: 'Lakers', shortName: 'LAL' });
  assert.equal(lal.city, 'LA');
  assert.equal(lal.name, '레이커스');
  assert.equal(lal.shortName, 'LA 레이커스');
  assert.equal(lal.abbreviation, 'LAL');
  assert.equal(lal.cityEn, 'Los Angeles');
});

test('선수: 사전 → Wikidata → 영문 순으로 이름을 고르고 국가·대학도 옮긴다', () => {
  const names = new Map([['1', '르브론 제임스']]);
  const wikidata = new Map([['2', '위키 이름']]);

  const a = { id: '1', name: 'LeBron James', college: null, birthCountry: 'USA', citizenship: null };
  assert.equal(localizePlayer(a, names, wikidata), 'dict');
  assert.equal(a.name, '르브론 제임스');
  assert.equal(a.nameEn, 'LeBron James');
  assert.equal(a.birthCountry, '미국');
  assert.equal(a.citizenship, null);

  const b = { id: '2', name: 'Wiki Guy', college: 'Kentucky' };
  assert.equal(localizePlayer(b, names, wikidata), 'wikidata');
  assert.equal(b.college, '켄터키대');

  const c = { id: '3', name: 'New Signing', college: 'Tiny College' };
  assert.equal(localizePlayer(c, names, wikidata), null);
  assert.equal(c.name, 'New Signing');
  // 사전에 없는 학교는 영문 그대로(지어내지 않는다)
  assert.equal(c.college, 'Tiny College');
});

test('지난 실행에서 이미 한국어가 된 국적을 다시 넣어도 그대로다', () => {
  const p = { id: '9', name: 'X', birthCountry: '슬로베니아', citizenship: 'Serbia' };
  localizePlayer(p, new Map());
  assert.equal(p.birthCountry, '슬로베니아');
  assert.equal(p.citizenship, '세르비아');
});

test('수집된 국가 표기가 모두 사전에 있다', () => {
  for (const name of ['Bosnia & Herzegovina', 'Türkiye', 'Democratic Republic of Congo', 'Trinidad & Tobago']) {
    assert.ok(COUNTRY_KO[name], name);
  }
});

test('Wikidata 실패는 빈 결과로 넘긴다', async () => {
  const result = await fetchWikidataKoreanNames(['123'], {
    fetchImpl: async () => {
      throw new Error('offline');
    },
  });
  assert.equal(result.size, 0);
});

test('Wikidata 응답에서 id별 한국어 이름을 읽는다', async () => {
  let sentUserAgent = '';
  const result = await fetchWikidataKoreanNames(['123', 'bad id'], {
    fetchImpl: async (_url, options) => {
      sentUserAgent = options.headers['User-Agent'];
      assert.match(decodeURIComponent(options.body), /"123"/);
      assert.doesNotMatch(decodeURIComponent(options.body), /bad id/);
      return {
        ok: true,
        json: async () => ({ results: { bindings: [{ espn: { value: '123' }, ko: { value: '홍길동' } }] } }),
      };
    },
  });
  assert.equal(result.get('123'), '홍길동');
  assert.match(sentUserAgent, /github\.com/);
});

test('공격/수비 리바운드: 트레이드된 시즌은 합계 줄을 쓴다', () => {
  const body = {
    categories: [
      {
        name: 'averages',
        names: ['gamesPlayed', 'avgOffensiveRebounds', 'avgDefensiveRebounds'],
        statistics: [
          { season: { displayName: '2024-25' }, teamId: '6', stats: ['22', '0.5', '7.8'] },
          { season: { displayName: '2025-26' }, teamId: '6', stats: ['22', '1.0', '7.0'] },
          { season: { displayName: '2025-26' }, teamId: '13', stats: ['28', '0.6', '7.2'] },
          { season: { displayName: '2025-26' }, stats: ['50', '0.8', '7.1'] },
        ],
      },
    ],
  };
  assert.deepEqual(reboundSplit(body, '2025-26'), { oreb: 0.8, dreb: 7.1 });
  assert.deepEqual(reboundSplit(body, '2024-25'), { oreb: 0.5, dreb: 7.8 });
  assert.equal(reboundSplit(body, '2019-20'), null);
});

test('한 경기 최다 득점은 정규시즌 경기만 본다', () => {
  const body = {
    names: ['minutes', 'points'],
    seasonTypes: [
      {
        displayName: '2025-26 Postseason',
        categories: [{ events: [{ stats: ['44', '61'] }] }],
      },
      {
        displayName: '2025-26 Regular Season',
        categories: [
          { events: [{ stats: ['36', '38'] }, { stats: ['40', '52'] }] },
          { events: [{ stats: ['30', '27'] }] },
        ],
      },
    ],
  };
  assert.equal(seasonHigh(body), 52);
  assert.equal(seasonHigh({ names: ['points'], seasonTypes: [] }), null);
});
