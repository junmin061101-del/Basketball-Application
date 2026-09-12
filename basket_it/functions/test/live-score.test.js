'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  KBL_TEAM_IDS,
  buildMessage,
  kblClock,
  nbaStatus,
  parseEspnGames,
  parseKblGame,
  planUpdates,
  quarterLabel,
  runLivePush,
  uuidV5,
} = require('../live-score');

test('UUID v5는 RFC 4122 기준값과 같다', () => {
  // DNS 네임스페이스로 "www.example.com"을 넣은 표준 검증값
  assert.equal(uuidV5('www.example.com'), '2ed6657d-e927-568b-95e1-2665a8aea6a2');
  assert.equal(uuidV5('nba:401'), uuidV5('nba:401'));
  assert.notEqual(uuidV5('nba:401'), uuidV5('nba:402'));
});

test('KBL 팀 코드 표가 수집기와 같다', () => {
  const { TEAMS } = require('../../tools/fetch-kbl');
  const fromCollector = Object.fromEntries(Object.entries(TEAMS).map(([code, t]) => [code, t.id]));
  assert.deepEqual(KBL_TEAM_IDS, fromCollector);
});

test('쿼터 표기: 1~4쿼터, 연장, 2차 연장, 하프타임, 쿼터 종료', () => {
  assert.equal(quarterLabel(3), '3쿼터');
  assert.equal(quarterLabel(5), '연장');
  assert.equal(quarterLabel(6), '2차 연장');
  const live = (period, clock, shortDetail) => ({ period, displayClock: clock, type: { state: 'in', shortDetail } });
  assert.deepEqual(nbaStatus(live(3, '7:12', '7:12 - 3rd')), ['live', '3쿼터', '7:12']);
  assert.deepEqual(nbaStatus(live(2, '0.0', 'Halftime')), ['live', '하프타임', '']);
  assert.deepEqual(nbaStatus(live(3, '0.0', 'End of 3rd Quarter')), ['live', '3쿼터 종료', '']);
  assert.deepEqual(nbaStatus({ type: { state: 'post' } }), ['final', '경기 종료', '']);
  assert.deepEqual(nbaStatus({ type: { state: 'pre' } }), ['scheduled', '', '']);
});

const espnBody = {
  events: [
    {
      id: '401',
      competitions: [
        {
          status: { period: 4, displayClock: '2:05', type: { state: 'in', shortDetail: '2:05 - 4th' } },
          competitors: [
            { homeAway: 'home', score: '101', team: { id: '13', abbreviation: 'LAL', logo: 'espn-lal.png' } },
            { homeAway: 'away', score: '99', team: { id: '2', abbreviation: 'BOS', logo: 'espn-bos.png' } },
          ],
        },
      ],
    },
  ],
};

test('ESPN 경기: 한국어 팀 이름·로고와 점수·쿼터·시간', () => {
  const [game] = parseEspnGames(espnBody, {
    13: { shortName: 'LA 레이커스', logo: 'lal.png' },
  });
  assert.equal(game.key, 'nba:401');
  assert.equal(game.homeTeamKey, 'nba:13');
  assert.equal(game.awayTeamKey, 'nba:2');
  assert.equal(game.homeName, 'LA 레이커스');
  assert.equal(game.homeLogo, 'lal.png');
  // 팀 표가 없으면 ESPN 약어·로고로 대신한다
  assert.equal(game.awayName, 'BOS');
  assert.deepEqual([game.homeScore, game.awayScore, game.status, game.period, game.clock], [101, 99, 'live', '4쿼터', '2:05']);
});

test('KBL 경기: 앱 로고 경로, 쿼터, 문자중계 남은 시간', () => {
  const row = { gmkey: 'S49G01N7', tcodeH: '50', tcodeA: '55', scoreH: 70, scoreA: 68, isStarted: 1, isEnded: 0, playingQuarter: '4' };
  const game = parseKblGame(row, kblClock([{ n: 1, m: 9, s: 30 }, { n: 2, m: 7, s: 5 }]));
  assert.equal(game.key, 'kbl:S49G01N7');
  assert.equal(game.homeTeamKey, 'kbl:lg');
  assert.equal(game.homeLogo, 'asset:assets/logos/kbl/lg.png');
  assert.deepEqual([game.status, game.period, game.clock], ['live', '4쿼터', '07:05']);
  assert.equal(parseKblGame({ ...row, isEnded: 1 }).status, 'final');
  assert.equal(parseKblGame({ ...row, tcodeA: '99' }), null);
});

const liveGame = (over = {}) => ({
  key: 'nba:401', league: 'nba', homeTeamKey: 'nba:13', awayTeamKey: 'nba:2', homeTeamId: '13', awayTeamId: '2',
  homeName: 'LA 레이커스', awayName: '보스턴', homeLogo: 'lal.png', awayLogo: 'bos.png',
  homeScore: 101, awayScore: 99, status: 'live', period: '4쿼터', clock: '2:05', ...over,
});
const stateOf = (g) => ({ homeScore: g.homeScore, awayScore: g.awayScore, period: g.period, clock: g.clock, status: g.status });

test('변화 감지: 처음·점수 변화는 높은 우선순위, 시간만 바뀌면 낮게, 같으면 안 보냄, 종료는 한 번', () => {
  const g = liveGame();
  assert.deepEqual(planUpdates([g], {}).map((p) => [p.event, p.scoreChanged]), [['update', true]]);
  assert.deepEqual(planUpdates([g], { 'nba:401': { state: stateOf(g) } }), []);
  const clockOnly = liveGame({ clock: '1:40' });
  assert.deepEqual(planUpdates([clockOnly], { 'nba:401': { state: stateOf(g) } }).map((p) => p.scoreChanged), [false]);
  const scored = liveGame({ homeScore: 103 });
  assert.deepEqual(planUpdates([scored], { 'nba:401': { state: stateOf(g) } }).map((p) => p.scoreChanged), [true]);
  const final = liveGame({ status: 'final', period: '경기 종료', clock: '' });
  assert.deepEqual(planUpdates([final], { 'nba:401': { state: stateOf(g) } }).map((p) => p.event), ['end']);
  assert.deepEqual(planUpdates([final], { 'nba:401': { state: stateOf(final) } }), []);
  // 시작 전 경기, 앱이 켜지기 전에 끝난 경기는 보내지 않는다
  assert.deepEqual(planUpdates([liveGame({ status: 'scheduled' }), final], {}), []);
});

test('Android 메시지: 플러그인 FCM 서비스 형식(event·content-state·activity-id)', () => {
  const { message } = buildMessage({ game: liveGame(), event: 'update', scoreChanged: true }, { platform: 'android', fcmToken: 'fcm-a' }, 1000);
  assert.equal(message.token, 'fcm-a');
  assert.equal(message.android.priority, 'high');
  assert.equal(message.data.event, 'update');
  assert.equal(message.data['activity-id'], 'nba:401');
  assert.equal(message.data.timestamp, '1000');
  const state = JSON.parse(message.data['content-state']);
  assert.deepEqual([state.homeName, state.homeScore, state.period, state.clock, state.homeLogo], ['LA 레이커스', 101, '4쿼터', '2:05', 'lal.png']);

  // 끝난 경기는 알림을 지우지 않고 최종 점수로 바꾼다
  const final = buildMessage({ game: liveGame({ status: 'final', period: '경기 종료', clock: '' }), event: 'end', scoreChanged: true }, { platform: 'android', fcmToken: 'fcm-a' }, 2000);
  assert.equal(final.message.data.event, 'update');
  assert.equal(JSON.parse(final.message.data['content-state']).status, 'final');
});

test('KBL 문자중계 시간은 가장 최근(n이 가장 큰) 줄을 쓴다', () => {
  assert.equal(kblClock([{ n: 3, m: 5, s: 1 }, { n: 9, m: 2, s: 40 }, { n: 7, m: 3, s: 0 }]), '02:40');
  assert.equal(kblClock([]), '');
  assert.equal(kblClock(null), '');
});

test('iPhone: 활동 토큰이 있으면 갱신, 없으면 push-to-start로 한 번만 시작', () => {
  const plan = { game: liveGame(), event: 'update', scoreChanged: false };
  const activityId = uuidV5('nba:401');
  const now = 1_800_000_000_000;

  const update = buildMessage(plan, { platform: 'ios', fcmToken: 'fcm-i', activityTokens: { [activityId]: 'act-token' } }, now);
  assert.equal(update.message.apns.liveActivityToken, 'act-token');
  assert.equal(update.message.apns.headers['apns-priority'], '5');
  assert.equal(update.message.apns.payload.aps.event, 'update');
  assert.equal(update.message.apns.payload.aps['content-state'].clock, '2:05');
  assert.equal(update.startedActivityId, undefined);

  const start = buildMessage(plan, { platform: 'ios', fcmToken: 'fcm-i', pushToStartToken: 'p2s' }, now);
  assert.equal(start.startedActivityId, activityId);
  assert.equal(start.message.apns.liveActivityToken, 'p2s');
  const aps = start.message.apns.payload.aps;
  assert.equal(aps.event, 'start');
  assert.equal(aps['attributes-type'], 'LiveActivitiesAppAttributes');
  assert.deepEqual(aps.attributes, { id: activityId, gameKey: 'nba:401' });

  // 방금 시작을 보냈는데 토큰이 아직 안 올라왔다 → 또 시작하지 않는다
  assert.equal(buildMessage(plan, { platform: 'ios', fcmToken: 'fcm-i', pushToStartToken: 'p2s', startedActivities: { [activityId]: now - 60_000 } }, now), null);
  // push-to-start를 못 쓰는 기기(iOS 17.2 미만)는 보낼 수 없다
  assert.equal(buildMessage(plan, { platform: 'ios', fcmToken: 'fcm-i' }, now), null);

  const end = buildMessage({ game: liveGame({ status: 'final' }), event: 'end', scoreChanged: true }, { platform: 'ios', fcmToken: 'fcm-i', activityTokens: { [activityId]: 'act-token' } }, now);
  assert.equal(end.message.apns.payload.aps.event, 'end');
  assert.equal(end.message.apns.payload.aps['dismissal-date'], Math.floor(now / 1000) + 900);
});

/** Firestore에서 쓰는 부분만 흉내 낸 가짜. */
function fakeDb(subscribers) {
  const collections = { liveSubscribers: new Map(Object.entries(subscribers)), liveGames: new Map() };
  const docRef = (name, id) => ({
    get: async () => ({ exists: collections[name].has(id), data: () => collections[name].get(id) }),
    set: async (value, options) => {
      const before = options?.merge ? collections[name].get(id) ?? {} : {};
      const merged = { ...before, ...value };
      if (options?.merge && value.startedActivities) {
        merged.startedActivities = { ...(before.startedActivities ?? {}), ...value.startedActivities };
      }
      collections[name].set(id, merged);
    },
    delete: async () => collections[name].delete(id),
  });
  return {
    collections,
    collection: (name) => ({
      doc: (id) => docRef(name, id),
      where: (field, op, values) => ({
        get: async () => ({
          docs: [...collections[name].entries()]
            .filter(([, v]) => (v[field] ?? []).some((k) => values.includes(k)))
            .map(([id, v]) => ({ id, data: () => v, ref: docRef(name, id) })),
        }),
      }),
    }),
  };
}

function fakeFetch({ espn = { events: [] }, kbl = [] } = {}) {
  return async (url) => {
    let body = {};
    if (url.includes('espn.com')) body = espn;
    else if (url.includes('/nba/teams.json')) body = { teams: [{ id: '13', shortName: 'LA 레이커스', logo: 'lal.png' }] };
    else if (url.includes('/kbl/teams.json')) body = { teams: [] };
    else if (url.includes('/match/list')) body = kbl;
    else if (url.includes('text-cast')) body = [];
    return { ok: true, json: async () => body };
  };
}

test('전체 흐름: 팔로우한 기기에만 보내고, 죽은 토큰은 지우고, 경기가 없으면 한 번만 확인', async () => {
  const db = fakeDb({
    'fcm-a': { platform: 'android', fcmToken: 'fcm-a', teamKeys: ['nba:13'] },
    'fcm-dead': { platform: 'android', fcmToken: 'fcm-dead', teamKeys: ['nba:2'] },
    'fcm-other': { platform: 'android', fcmToken: 'fcm-other', teamKeys: ['nba:7', 'kbl:sk'] },
  });
  const sentTokens = [];
  const messaging = {
    sendEach: async (messages) => ({
      responses: messages.map((m) => {
        sentTokens.push(m.token);
        return m.token === 'fcm-dead'
          ? { success: false, error: { code: 'messaging/registration-token-not-registered' } }
          : { success: true };
      }),
    }),
  };
  const sleeps = [];
  const rounds = await runLivePush({
    db, messaging, fetchImpl: fakeFetch({ espn: espnBody }), now: () => 1000, sleep: async (ms) => sleeps.push(ms),
  });

  // 진행 중 경기가 있어 30초 뒤 한 번 더 확인했지만, 값이 같아 두 번째에는 보내지 않는다
  assert.equal(rounds.length, 2);
  assert.deepEqual(sleeps, [30000]);
  assert.deepEqual(sentTokens.sort(), ['fcm-a', 'fcm-dead']);
  assert.equal(rounds[0].removed, 1);
  assert.equal(db.collections.liveSubscribers.has('fcm-dead'), false);
  assert.equal(rounds[1].sent, 0);
  assert.equal(db.collections.liveGames.get('nba:401').state.homeScore, 101);

  const quiet = await runLivePush({ db, messaging, fetchImpl: fakeFetch(), now: () => 2000, sleep: async (ms) => sleeps.push(ms) });
  assert.equal(quiet.length, 1);
  assert.deepEqual(sleeps, [30000]);
});

test('iPhone 시작을 보내면 기기 문서에 기록해 다음 확인 때 중복 시작하지 않는다', async () => {
  const db = fakeDb({ 'fcm-i': { platform: 'ios', fcmToken: 'fcm-i', pushToStartToken: 'p2s', teamKeys: ['nba:13'] } });
  let count = 0;
  const messaging = { sendEach: async (m) => { count += m.length; return { responses: m.map(() => ({ success: true })) }; } };
  let clock = 1_800_000_000_000;
  const scores = [101, 103];
  let call = 0;
  const fetchImpl = async (url) => {
    if (url.includes('espn.com')) {
      const body = JSON.parse(JSON.stringify(espnBody));
      body.events[0].competitions[0].competitors[0].score = String(scores[Math.min(call++, 1)]);
      return { ok: true, json: async () => body };
    }
    return fakeFetch()(url);
  };
  await runLivePush({ db, messaging, fetchImpl, now: () => (clock += 30000), sleep: async () => {} });
  // 첫 확인에서 시작 1번, 점수가 바뀐 두 번째 확인에서는 토큰이 아직 없어 보내지 않는다
  assert.equal(count, 1);
  assert.ok(db.collections.liveSubscribers.get('fcm-i').startedActivities[uuidV5('nba:401')]);
});
