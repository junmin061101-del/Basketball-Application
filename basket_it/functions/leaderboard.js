'use strict';

/**
 * 승부예측 랭킹을 서버에서 채점한다.
 *
 * 전에는 앱이 랭킹을 열 때마다 투표 전체를 읽어 직접 채점했다. 그러면
 * (1) 읽기 비용이 "투표 수 × 랭킹을 연 횟수"로 불어나고, (2) 마감 검사가
 * 화면에만 있어 경기가 끝난 뒤 Firestore에 직접 쓴 투표도 맞힌 것으로 셌다.
 * 이제 예약 함수가 투표를 한 번 읽어 채점하고 결과 문서 하나만 앱이 읽는다.
 *
 * 마감: 경기 시작 1시간 전(앱의 Game.predictionDeadline과 같다). 투표의
 * createdAt은 보안 규칙이 서버 시각(request.time)만 허용하므로 믿을 수 있다.
 */

const PAGES_BASE = 'https://junmin061101-del.github.io/Basketball-Application';
const crypto = require('crypto');

const VOTES = 'predictionVotes';
const LEADERBOARD = 'leaderboard';
/** 경기별 투표 수(홈·원정). 앱은 투표 목록 대신 이 문서 하나를 읽는다. */
const TALLIES = 'predictionTallies';
const DEADLINE_MS = 60 * 60 * 1000;
/** 문서 하나(1MB)에 담는 최대 인원. */
const MAX_ENTRIES = 500;

/**
 * votes: [{ uid, displayName, gameId, pick: 'home'|'away', createdAtMs }]
 * games: games.json의 games 배열
 * 반환: 맞힌 수 내림차순 → 이름 가나다순. 결과 미확정 투표만 있는 사람도 0으로 남긴다.
 */
function scoreLeaderboard(votes, games) {
  const byId = new Map(games.map((g) => [g.id, g]));
  const people = new Map();
  for (const v of votes) {
    const p = people.get(v.uid) ?? { uid: v.uid, displayName: v.displayName, correct: 0, settled: 0 };
    p.displayName = v.displayName || p.displayName;
    people.set(v.uid, p);

    const g = byId.get(v.gameId);
    if (!g || g.status !== 'finished' || g.homeScore === g.awayScore) continue;
    const deadline = Date.parse(g.startTime) - DEADLINE_MS;
    // 마감 뒤에 들어온(또는 시각을 모르는) 투표는 채점하지 않는다.
    if (!(v.createdAtMs <= deadline)) continue;
    const winner = g.homeScore > g.awayScore ? 'home' : 'away';
    p.settled += 1;
    if (v.pick === winner) p.correct += 1;
  }
  return [...people.values()].sort(
    (a, b) => b.correct - a.correct || a.displayName.localeCompare(b.displayName, 'ko'),
  );
}

/** 경기별 홈·원정 투표 수. { gameId: { home, away } } */
function tallyVotes(votes) {
  const tallies = {};
  for (const v of votes) {
    if (v.pick !== 'home' && v.pick !== 'away') continue;
    const t = (tallies[v.gameId] ??= { home: 0, away: 0 });
    t[v.pick] += 1;
  }
  return tallies;
}

/**
 * 새로 끝난 경기가 있을 때만 투표 전체를 읽어 다시 채점한다. 그 사이에는
 * 문서 하나만 읽고 끝난다(30분마다 투표 N건을 읽으면 투표가 늘수록 비용이
 * 그대로 불어난다). 다시 채점할 때 경기별 투표 수(predictionTallies)도 새로
 * 적어, 트리거가 놓친 증감이 있으면 바로잡는다.
 * 반환: 채점한 인원 수, 건너뛰면 null.
 */
/**
 * 승부예측 대상 경기(KBL·NBA). NBA 경기 id는 앱처럼 "nba-"를 붙인다(투표의 gameId와 같게).
 * 하나라도 못 받으면 던진다(빈 목록으로 채점하면 랭킹이 0으로 덮인다).
 */
async function loadGames(fetchImpl) {
  const get = async (league, prefix) => {
    const res = await fetchImpl(`${PAGES_BASE}/${league}/games.json`, { signal: AbortSignal.timeout(20000) });
    if (!res.ok) throw new Error(`${league}/games.json HTTP ${res.status}`);
    const { games = [] } = await res.json();
    return games.map((g) => ({ ...g, id: `${prefix}${g.id}` }));
  };
  return { kbl: await get('kbl', ''), nba: await get('nba', 'nba-') };
}

const leagueOf = (gameId) => (String(gameId).startsWith('nba-') ? 'nba' : 'kbl');

async function updateLeaderboard({ db, fetchImpl = fetch }) {
  const byLeague = await loadGames(fetchImpl);
  const games = [...byLeague.kbl, ...byLeague.nba];

  const finished = games.filter((g) => g.status === 'finished').map((g) => g.id).sort();
  const finishedKey = crypto.createHash('sha1').update(finished.join(',')).digest('hex');
  const boardRef = db.collection(LEADERBOARD).doc('kbl'); // 마지막 채점 표시는 kbl 문서에 둔다
  const board = await boardRef.get();
  if (board.exists && board.get('finishedKey') === finishedKey) return null;

  // ponytail: 다시 채점할 때는 투표 전체를 읽는다(경기가 끝날 때마다 N건).
  // 투표가 수백만 건이 되면 끝난 경기의 투표만 읽어 누적하는 방식으로 바꾼다.
  const snap = await db.collection(VOTES).get();
  const votes = snap.docs.map((d) => {
    const x = d.data();
    return {
      uid: x.uid,
      displayName: typeof x.displayName === 'string' ? x.displayName : '사용자',
      gameId: x.gameId,
      pick: x.pick,
      createdAtMs: x.createdAt?.toMillis?.() ?? NaN,
    };
  });
  // 리그별로 따로 채점한다(앱의 KBL / NBA 랭킹).
  const boards = {};
  for (const league of ['kbl', 'nba']) {
    boards[league] = scoreLeaderboard(votes.filter((v) => leagueOf(v.gameId) === league), byLeague[league]).slice(0, MAX_ENTRIES);
  }
  const tallies = Object.entries(tallyVotes(votes));
  for (let i = 0; i < tallies.length; i += 500) {
    const batch = db.batch();
    for (const [gameId, t] of tallies.slice(i, i + 500)) batch.set(db.collection(TALLIES).doc(gameId), t);
    await batch.commit();
  }
  await db.collection(LEADERBOARD).doc('nba').set({ updatedAt: new Date(), entries: boards.nba });
  await boardRef.set({ updatedAt: new Date(), finishedKey, entries: boards.kbl });
  return boards.kbl.length + boards.nba.length;
}

/**
 * 투표 하나가 생기거나 바뀌거나 지워질 때 그 경기의 투표 수를 고친다.
 * before/after는 문서 데이터(없으면 undefined).
 */
function tallyChange(before, after) {
  const changes = [];
  const pickOf = (d) => (d && (d.pick === 'home' || d.pick === 'away') ? d.pick : null);
  const [b, a] = [pickOf(before), pickOf(after)];
  if (b && (b !== a || before.gameId !== after?.gameId)) changes.push([before.gameId, b, -1]);
  if (a && (a !== b || before?.gameId !== after.gameId)) changes.push([after.gameId, a, 1]);
  return changes;
}

async function applyTallyChange(db, FieldValue, before, after) {
  for (const [gameId, side, delta] of tallyChange(before, after)) {
    await db.collection(TALLIES).doc(gameId).set({ [side]: FieldValue.increment(delta) }, { merge: true });
  }
}

/**
 * 마감 뒤에 채점 대상 투표를 지우거나 바꾸면 되돌릴 원래 투표, 아니면 null.
 *
 * 보안 규칙은 경기 시각을 몰라 마감 뒤 삭제·수정을 막지 못한다. 그러면 경기가
 * 끝난 뒤 틀린 투표만 지워(또는 다시 써서 채점에서 빼) 적중률을 올릴 수 있다.
 * 그래서 서버가 그런 변경을 되돌린다. 되돌린 쓰기는 before가 이미 마감 뒤
 * 투표라 다시 되돌리지 않는다(돌고 돌지 않는다).
 */
function lockedVote(before, after, game, nowMs) {
  if (!before || !game) return null;
  const deadline = Date.parse(game.startTime) - DEADLINE_MS;
  const createdAtMs = before.createdAt?.toMillis?.() ?? NaN;
  if (!(createdAtMs <= deadline) || !(nowMs > deadline)) return null;
  if (after && after.pick === before.pick && after.createdAt?.toMillis?.() === createdAtMs) return null;
  return before;
}

/**
 * 투표 트리거에서 부른다. 되돌렸으면 true. 탈퇴 정리(계정이 이미 없음)가 지운
 * 투표는 되돌리지 않는다.
 */
async function guardLockedVote({ auth, ref, before, after, fetchImpl = fetch, nowMs = Date.now() }) {
  if (!before) return false;
  const games = (await loadGames(fetchImpl))[leagueOf(before.gameId)];
  const restore = lockedVote(before, after, games.find((g) => g.id === before.gameId), nowMs);
  if (!restore) return false;
  try {
    await auth.getUser(before.uid);
  } catch (e) {
    if (e.code === 'auth/user-not-found') return false;
    throw e;
  }
  await ref.set(restore);
  return true;
}

module.exports = { scoreLeaderboard, updateLeaderboard, tallyVotes, tallyChange, applyTallyChange, lockedVote, guardLockedVote, DEADLINE_MS };
