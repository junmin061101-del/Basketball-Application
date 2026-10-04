'use strict';

/**
 * 팔로우한 팀의 실시간 경기(KBL)를 잠금화면으로 보내는 로직.
 *
 * 1분마다 도는 함수(index.js의 pushLiveScores)가 진행 중인 경기를 확인해,
 * 점수·쿼터·시간이 바뀌었으면 그 팀을 팔로우한 기기에 FCM으로 보낸다.
 *
 * - Android: 데이터 메시지. live_activities 플러그인의 FCM 서비스가 받아
 *   앱의 LiveScoreActivityManager(Kotlin)로 잠금화면 상시 알림을 그린다.
 * - iPhone: FCM의 Live Activity 푸시. 경기가 시작되면 push-to-start 토큰으로
 *   Live Activity를 띄우고(iOS 17.2+), 이후에는 그 활동의 토큰으로 갱신한다.
 *
 * 입출력(네트워크·Firestore·FCM)은 모두 인자로 받아 테스트에서 가짜로 바꾼다.
 */

const crypto = require('crypto');

const PAGES_BASE = 'https://junmin061101-del.github.io/Basketball-Application';
const KBL_API = 'https://api.kbl.or.kr';

/** iOS 위젯 확장의 ActivityAttributes 이름. 플러그인과 위젯이 같은 이름을 쓴다. */
const ATTRIBUTES_TYPE = 'LiveActivitiesAppAttributes';

/** 구독 문서 컬렉션(문서 id = FCM 토큰)과 마지막으로 보낸 경기 상태 컬렉션. */
const SUBSCRIBERS = 'liveSubscribers';
const LIVE_GAMES = 'liveGames';

/** 진행 중인 경기의 선수 기록. 앱이 이 문서를 구독해 경기 중에도 기록을 본다. */
const LIVE_BOX_SCORES = 'liveBoxScores';

/**
 * KBL 팀 코드 → 앱 팀 id. tools/fetch-kbl.js의 TEAMS와 같아야 한다
 * (테스트가 둘을 비교한다). 함수 배포 묶음에는 tools 폴더가 들어가지 않아 따로 둔다.
 */
const KBL_TEAM_IDS = {
  55: 'sk',
  70: 'kgc',
  16: 'db',
  50: 'lg',
  60: 'kcc',
  '06': 'kt',
  64: 'kogas',
  66: 'sono',
  10: 'mobis',
  35: 'samsung',
};

/** 같은 기기에 Live Activity를 다시 시작하지 않는 기간. 토큰이 늦게 올라와도 중복을 막는다. */
const RESTART_GUARD_MS = 6 * 60 * 60 * 1000;

/**
 * RFC 4122 UUID v5. 경기 키로 늘 같은 UUID를 만든다.
 * 서버가 Live Activity 속성 id로 넣고, 앱이 그 id와 갱신 토큰을 함께 올려
 * "어느 경기의 토큰인지"를 잇는 데 쓴다.
 */
function uuidV5(name, namespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8') {
  const ns = Buffer.from(namespace.replace(/-/g, ''), 'hex');
  const hash = crypto
    .createHash('sha1')
    .update(Buffer.concat([ns, Buffer.from(String(name), 'utf8')]))
    .digest();
  const bytes = Buffer.from(hash.subarray(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const h = bytes.toString('hex');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20)}`;
}

/** 쿼터 번호 → "3쿼터" / "연장" / "2차 연장". */
function quarterLabel(period) {
  const p = Number(period) || 0;
  if (p <= 0) return '';
  if (p <= 4) return `${p}쿼터`;
  return p === 5 ? '연장' : `${p - 4}차 연장`;
}

/** KBL 일정 한 건 → 경기. KBL 10개 구단끼리가 아니면 null. */
function parseKblGame(row, clock = '') {
  const homeId = KBL_TEAM_IDS[row?.tcodeH];
  const awayId = KBL_TEAM_IDS[row?.tcodeA];
  if (!homeId || !awayId || !row.gmkey) return null;
  let status = 'scheduled';
  if (row.isEnded === 1) status = 'final';
  else if (row.isStarted === 1) status = 'live';
  const q = String(row.playingQuarter ?? '');
  let period = '';
  if (status === 'final') period = '경기 종료';
  else if (/^[1-4]$/.test(q)) period = `${q}쿼터`;
  else if (/^(OT|E)\d*$/i.test(q)) period = '연장';
  const side = (id, score, name) => ({
    teamId: id,
    name: name ?? id,
    // 앱에 넣어 둔 KBL 공식 아이콘(lib/data/team_logo_assets.dart와 같은 경로).
    logo: `asset:assets/logos/kbl/${id}.png`,
    score: Number(score) || 0,
  });
  return makeGame(
    'kbl',
    row.gmkey,
    side(homeId, row.scoreH, row.tnameH),
    side(awayId, row.scoreA, row.tnameA),
    status,
    period,
    status === 'live' ? clock : '',
  );
}

/**
 * KBL 문자중계(/match/{gmkey}/text-cast)의 가장 최근 줄(n이 가장 큰 줄)의
 * 남은 시간("m" 분, "s" 초) → "07:12". 없으면 빈 문자열.
 */
function kblClock(textCast) {
  const rows = Array.isArray(textCast) ? textCast : [];
  const last = rows.reduce((best, row) => (best == null || Number(row?.n) > Number(best.n) ? row : best), null);
  if (!last || last.m == null || last.s == null) return '';
  return `${String(last.m).padStart(2, '0')}:${String(last.s).padStart(2, '0')}`;
}

function makeGame(league, id, home, away, status, period, clock) {
  return {
    key: `${league}:${id}`,
    league,
    gameId: String(id),
    homeTeamKey: `${league}:${home.teamId}`,
    awayTeamKey: `${league}:${away.teamId}`,
    homeTeamId: home.teamId,
    awayTeamId: away.teamId,
    homeName: home.name,
    awayName: away.name,
    homeLogo: home.logo,
    awayLogo: away.logo,
    homeScore: home.score,
    awayScore: away.score,
    status,
    period,
    clock,
  };
}

/** 잠금화면이 매번 다시 그리는 값. 이게 바뀌었을 때만 보낸다. */
function contentState(game) {
  return {
    homeScore: game.homeScore,
    awayScore: game.awayScore,
    period: game.period,
    clock: game.clock,
    status: game.status,
  };
}

/**
 * 지난번 보낸 상태와 비교해 보낼 경기를 고른다.
 *
 * - 진행 중인데 처음 보거나 값이 바뀌었으면 update. 점수·쿼터가 바뀐 경우만
 *   scoreChanged(아이폰에서 높은 우선순위로 보낸다). 남은 시간만 바뀐 건 낮은
 *   우선순위로 보내 Apple의 푸시 한도를 아낀다.
 * - 진행 중이던 경기가 끝났으면 end 한 번.
 * - 시작 전 경기, 이미 끝을 알린 경기는 건너뛴다.
 */
function planUpdates(games, previousByKey) {
  const plans = [];
  for (const game of games) {
    const prev = previousByKey[game.key];
    const state = contentState(game);
    if (game.status === 'live') {
      if (prev && JSON.stringify(prev.state) === JSON.stringify(state)) continue;
      const scoreChanged =
        !prev ||
        prev.state?.homeScore !== state.homeScore ||
        prev.state?.awayScore !== state.awayScore ||
        prev.state?.period !== state.period;
      plans.push({ game, event: 'update', scoreChanged });
    } else if (game.status === 'final' && prev && prev.state?.status === 'live') {
      plans.push({ game, event: 'end', scoreChanged: true });
    }
  }
  return plans;
}

/** Android 알림과 iPhone Live Activity가 함께 쓰는 표시값. */
function displayState(game) {
  return {
    ...contentState(game),
    league: game.league,
    homeName: game.homeName,
    awayName: game.awayName,
    homeTeamId: game.homeTeamId,
    awayTeamId: game.awayTeamId,
    homeLogo: game.homeLogo,
    awayLogo: game.awayLogo,
  };
}

/**
 * 구독 기기 한 대에 보낼 메시지. 보낼 게 없으면 null.
 * 반환값의 startedActivityId가 있으면 이번에 iPhone Live Activity를 새로 시작한 것이다.
 */
function buildMessage(plan, subscriber, nowMs) {
  const { game, event, scoreChanged } = plan;
  const token = subscriber.fcmToken;
  if (!token) return null;

  if (subscriber.platform === 'android') {
    return {
      message: {
        token,
        android: { priority: 'high', ttl: 60 * 1000 },
        data: {
          // 플러그인의 end는 알림을 바로 지운다. 끝난 경기도 최종 점수를 잠시
          // 보여주도록 update(status: final)로 보내고, 앱이 15분 뒤 스스로 내린다.
          event: 'update',
          'content-state': JSON.stringify(displayState(game)),
          'activity-id': game.key,
          'activity-tag': 'live_score',
          timestamp: String(nowMs),
        },
      },
    };
  }

  if (subscriber.platform !== 'ios') return null;
  const seconds = Math.floor(nowMs / 1000);
  const activityId = uuidV5(game.key);
  const activityToken = subscriber.activityTokens?.[activityId];

  if (activityToken) {
    const aps = { timestamp: seconds, event, 'content-state': displayState(game) };
    // 끝난 경기는 최종 점수를 15분 보여준 뒤 잠금화면에서 내린다.
    if (event === 'end') aps['dismissal-date'] = seconds + 15 * 60;
    return {
      message: {
        token,
        apns: {
          liveActivityToken: activityToken,
          headers: { 'apns-priority': scoreChanged ? '10' : '5' },
          payload: { aps },
        },
      },
    };
  }

  // 아직 활동이 없다: 진행 중이면 push-to-start로 새로 띄운다. 최근에 이미
  // 시작을 보냈다면(토큰이 아직 안 올라온 것) 다시 보내지 않는다.
  const startedAt = subscriber.startedActivities?.[activityId] ?? 0;
  if (event !== 'update' || !subscriber.pushToStartToken || nowMs - startedAt < RESTART_GUARD_MS) {
    return null;
  }
  return {
    startedActivityId: activityId,
    message: {
      token,
      apns: {
        liveActivityToken: subscriber.pushToStartToken,
        headers: { 'apns-priority': '10' },
        payload: {
          aps: {
            timestamp: seconds,
            event: 'start',
            'content-state': displayState(game),
            'attributes-type': ATTRIBUTES_TYPE,
            attributes: { id: activityId, gameKey: game.key },
            alert: {
              title: `${game.awayName} vs ${game.homeName}`,
              body: '팔로우한 팀 경기가 시작됐어요',
            },
          },
        },
      },
    },
  };
}

/** 토큰이 더는 유효하지 않다는 FCM 오류. 이런 기기는 구독을 지운다. */
function isDeadTokenError(error) {
  const code = error?.code ?? error?.errorInfo?.code ?? '';
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token'
  );
}

async function getJson(fetchImpl, url, headers = {}) {
  const res = await fetchImpl(url, { headers, signal: AbortSignal.timeout(10000) });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${url}`);
  return res.json();
}

const KBL_HEADERS = { Channel: 'WEB', TeamCode: 'XX', lang: 'ko', 'X-Requested-With': 'XMLHttpRequest' };

/** 한국 날짜 "YYYYMMDD". */
function kstDate(nowMs) {
  return new Date(nowMs + 9 * 3600 * 1000).toISOString().slice(0, 10).replace(/-/g, '');
}

/**
 * 지금 KBL 경기(오늘 일정). 앱에서 NBA를 내려 ESPN은 더 부르지 않는다.
 */
async function fetchGames(fetchImpl, nowMs) {
  const games = [];
  try {
    const day = kstDate(nowMs);
    const [list, teams] = await Promise.all([
      getJson(fetchImpl, `${KBL_API}/match/list?fromDate=${day}&toDate=${day}&tcodeList=all`, KBL_HEADERS),
      getJson(fetchImpl, `${PAGES_BASE}/kbl/teams.json`).catch(() => ({ teams: [] })),
    ]);
    const nameOf = Object.fromEntries((teams.teams ?? []).map((t) => [t.id, t.shortName]));
    for (const row of Array.isArray(list) ? list : []) {
      let clock = '';
      if (row.isStarted === 1 && row.isEnded !== 1) {
        clock = kblClock(
          await getJson(fetchImpl, `${KBL_API}/match/${row.gmkey}/text-cast`, KBL_HEADERS).catch(() => []),
        );
      }
      const game = parseKblGame(row, clock);
      if (!game) continue;
      game.homeName = nameOf[game.homeTeamId] ?? game.homeName;
      game.awayName = nameOf[game.awayTeamId] ?? game.awayName;
      games.push(game);
    }
  } catch (error) {
    console.warn(`KBL 일정 실패: ${error.message}`);
  }
  return games;
}

/**
 * KBL 선수 기록 한 줄.
 *
 * tools/fetch-kbl.js의 toBoxLine과 같은 모양이어야 한다(테스트가 두 결과를
 * 비교한다). 함수 배포 묶음에 tools 폴더가 들어가지 않아 여기에 따로 둔다.
 */
function toLiveBoxLine(row) {
  const r = row?.records ?? {};
  const p = row?.player ?? {};
  const seconds = (Number(r.playMin) || 0) * 60 + (Number(r.playSec) || 0);
  if (seconds === 0) return null;
  const n = (v) => Number(v) || 0;
  return {
    playerId: String(p.pcode),
    name: p.pname ?? '',
    headshot: p.img ?? null,
    teamId: KBL_TEAM_IDS[p.tcode] ?? '',
    starter: String(row.startFlag) === '1',
    minutes: Math.round(seconds / 60),
    seconds,
    points: n(r.score),
    // fg/fgA는 2점슛만, fgt/fgtA가 3점을 포함한 전체 야투다.
    fgm: n(r.fgt),
    fga: n(r.fgtA),
    tpm: n(r.threep),
    tpa: n(r.threepA),
    ftm: n(r.ft),
    fta: n(r.ftA),
    oreb: n(r.offr),
    dreb: n(r.defr),
    ast: n(r.ast),
    tov: n(r.to),
    stl: n(r.stl),
    blk: n(r.bs),
    pf: n(r.foul),
    // 득실마진을 모르면 KBL은 999를 준다. 그대로 두면 "+999"로 보여 비워 둔다.
    plusMinus: Number(r.marginCn) === 999 ? null : n(r.marginCn),
  };
}

/** 경기 하나의 지금까지 선수 기록. */
async function fetchKblBoxScore(fetchImpl, gameId) {
  const rows = await getJson(fetchImpl, `${KBL_API}/match/${gameId}/player-stat`, KBL_HEADERS);
  return (Array.isArray(rows) ? rows : []).map(toLiveBoxLine).filter(Boolean);
}

/**
 * 진행 중(이거나 막 끝난) 경기의 선수 기록을 Firestore에 적는다.
 *
 * 앱이 읽는 정적 JSON은 수집기(GitHub Actions)가 올리는데, 20분 간격으로
 * 걸어 둬도 몇 시간씩 밀릴 때가 있다. 그 사이를 여기서 메운다.
 *
 * 반환: 최종 기록까지 적어 둔 경기 키들. 다시 받지 않으려고 기억해 둔다.
 */
async function writeBoxScores({ db, fetchImpl, games, nowMs }) {
  const finalKeys = new Set();
  for (const game of games) {
    if (game.league !== 'kbl') continue;
    try {
      const lines = await fetchKblBoxScore(fetchImpl, game.gameId);
      if (lines.length === 0) continue;
      const isFinal = game.status === 'final';
      await db.collection(LIVE_BOX_SCORES).doc(game.key).set({
        gameId: game.gameId,
        lines,
        final: isFinal,
        updatedAt: nowMs,
      });
      if (isFinal) finalKeys.add(game.key);
    } catch (error) {
      console.warn(`선수 기록 실패 ${game.key}: ${error.message}`);
    }
  }
  return finalKeys;
}

/**
 * 한 번 확인하고 보낸다. 반환: { live, sent, removed }.
 * [db]는 firebase-admin Firestore, [messaging]은 admin.messaging().
 */
async function pushOnce({ db, messaging, fetchImpl, nowMs }) {
  const games = await fetchGames(fetchImpl, nowMs);
  const candidates = games.filter((g) => g.status !== 'scheduled');
  const live = games.filter((g) => g.status === 'live').length;
  if (candidates.length === 0) return { live, sent: 0, removed: 0 };

  const previousByKey = {};
  for (const game of candidates) {
    const snap = await db.collection(LIVE_GAMES).doc(game.key).get();
    if (snap.exists) previousByKey[game.key] = snap.data();
  }

  // 선수 기록을 받아 올 경기: 진행 중이거나 방금 끝난 경기, 그리고 끝났는데
  // 아직 최종 기록을 못 받아 둔 경기(함수가 그 경기 중에 못 돌았을 때)다.
  const finalBoxKeys = await writeBoxScores({
    db,
    fetchImpl,
    nowMs,
    games: candidates.filter(
      (g) =>
        g.status === 'live' ||
        previousByKey[g.key]?.state?.status === 'live' ||
        (g.status === 'final' && previousByKey[g.key]?.boxFinal !== true),
    ),
  });
  const plans = planUpdates(candidates, previousByKey);

  let sent = 0;
  let removed = 0;
  for (const plan of plans) {
    const snap = await db
      .collection(SUBSCRIBERS)
      .where('teamKeys', 'array-contains-any', [plan.game.homeTeamKey, plan.game.awayTeamKey])
      .get();
    const built = [];
    for (const doc of snap.docs) {
      const result = buildMessage(plan, doc.data(), nowMs);
      if (result) built.push({ doc, ...result });
    }
    if (built.length > 0) {
      const response = await messaging.sendEach(built.map((b) => b.message));
      for (let i = 0; i < built.length; i++) {
        const r = response.responses[i];
        if (r.success) {
          sent += 1;
          if (built[i].startedActivityId) {
            await built[i].doc.ref.set(
              { startedActivities: { [built[i].startedActivityId]: nowMs } },
              { merge: true },
            );
          }
        } else if (isDeadTokenError(r.error)) {
          await built[i].doc.ref.delete();
          removed += 1;
        } else {
          console.warn(`푸시 실패 ${plan.game.key}: ${r.error?.message ?? r.error}`);
        }
      }
    }
  }

  // 시작한 경기는 푸시와 상관없이 상태를 적어 둔다. 앱은 정적 JSON이 늦어도
  // 이 값으로 오늘 경기의 점수와 종료를 보여준다. 바뀐 게 없으면 적지 않는다.
  for (const game of candidates) {
    const prev = previousByKey[game.key];
    const state = contentState(game);
    const boxFinal = prev?.boxFinal === true || finalBoxKeys.has(game.key);
    const same =
      prev &&
      JSON.stringify(prev.state) === JSON.stringify(state) &&
      (prev.boxFinal ?? false) === boxFinal;
    if (same) continue;
    await db.collection(LIVE_GAMES).doc(game.key).set({ state, boxFinal, updatedAt: nowMs });
  }
  return { live, sent, removed };
}

/**
 * 1분에 한 번 불린다. 진행 중인 경기가 있으면 30초 뒤 한 번 더 확인해 30초
 * 간격으로 갱신한다. 경기가 없으면 곧바로 끝내 비용이 들지 않게 한다.
 */
async function runLivePush({ db, messaging, fetchImpl = fetch, now = () => Date.now(), sleep, gapMs = 30000 }) {
  const wait = sleep ?? ((ms) => new Promise((r) => setTimeout(r, ms)));
  const first = await pushOnce({ db, messaging, fetchImpl, nowMs: now() });
  if (first.live === 0) return [first];
  await wait(gapMs);
  const second = await pushOnce({ db, messaging, fetchImpl, nowMs: now() });
  return [first, second];
}

module.exports = {
  ATTRIBUTES_TYPE,
  LIVE_BOX_SCORES,
  KBL_TEAM_IDS,
  LIVE_GAMES,
  SUBSCRIBERS,
  buildMessage,
  contentState,
  fetchKblBoxScore,
  kblClock,
  kstDate,
  toLiveBoxLine,
  parseKblGame,
  planUpdates,
  pushOnce,
  quarterLabel,
  runLivePush,
  uuidV5,
};
