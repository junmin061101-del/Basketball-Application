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
const VOTES = 'predictionVotes';
const LEADERBOARD = 'leaderboard';
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

async function updateLeaderboard({ db, fetchImpl = fetch }) {
  const res = await fetchImpl(`${PAGES_BASE}/kbl/games.json`, { signal: AbortSignal.timeout(20000) });
  if (!res.ok) throw new Error(`games.json HTTP ${res.status}`);
  const { games = [] } = await res.json();

  // ponytail: 매번 투표 전체를 읽는다(30분마다 N건). 투표가 수십만 건이 되면
  // 경기가 끝날 때만 그 경기 투표를 읽어 누적하는 방식으로 바꾼다.
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
  const entries = scoreLeaderboard(votes, games).slice(0, MAX_ENTRIES);
  await db.collection(LEADERBOARD).doc('kbl').set({ updatedAt: new Date(), entries });
  return entries.length;
}

module.exports = { scoreLeaderboard, updateLeaderboard, DEADLINE_MS };
