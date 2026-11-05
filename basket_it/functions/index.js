'use strict';

/**
 * Baskit 백엔드 예약 함수.
 *
 * - pushLiveScores: 팔로우한 팀의 실시간 경기를 잠금화면으로 보낸다(live-score.js).
 * - updatePredictionLeaderboard: 승부예측 랭킹을 서버에서 채점한다(leaderboard.js).
 * - cleanUpDeletedUser: 탈퇴한 사람의 데이터를 정리한다(account-cleanup.js).
 *
 * 뉴스는 GitHub Actions 수집기(tools/fetch-news.js)가 정적 JSON으로 올린다.
 * 예전 뉴스 함수(getBasketballNews)는 앱이 쓰지 않게 되어 지웠다.
 */

const { onSchedule } = require('firebase-functions/v2/scheduler');
const functionsV1 = require('firebase-functions/v1');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

const { runLivePush } = require('./live-score');
const { updateLeaderboard } = require('./leaderboard');
const { cleanUpDeletedUser } = require('./account-cleanup');

admin.initializeApp();
const db = admin.firestore();

/**
 * 팔로우한 팀의 실시간 경기를 잠금화면(Android 상시 알림·iPhone Live Activity)으로
 * 보낸다. 1분마다 깨어나 진행 중인 경기가 없으면 곧바로 끝나고, 있으면 30초
 * 간격으로 두 번 확인한다. 로직은 live-score.js에 있다.
 */
exports.pushLiveScores = onSchedule(
  {
    schedule: 'every 1 minutes',
    region: 'asia-northeast3',
    timeZone: 'Asia/Seoul',
    timeoutSeconds: 120,
    memory: '256MiB',
    // 1분마다 도는 짧은 작업이라 1세대 CPU로 비용을 낮춘다.
    cpu: 'gcf_gen1',
    retryCount: 0,
  },
  async () => {
    const rounds = await runLivePush({ db, messaging: admin.messaging() });
    const sent = rounds.reduce((sum, r) => sum + r.sent, 0);
    if (sent > 0 || rounds[0].live > 0) {
      logger.info('실시간 스코어 푸시', { rounds });
    }
  },
);

/**
 * 승부예측 랭킹을 30분마다 다시 채점해 leaderboard/kbl 문서 하나에 적는다.
 * 앱은 이 문서만 읽는다. 채점 규칙은 leaderboard.js에 있다.
 */
exports.updatePredictionLeaderboard = onSchedule(
  {
    schedule: 'every 30 minutes',
    region: 'asia-northeast3',
    timeZone: 'Asia/Seoul',
    timeoutSeconds: 120,
    memory: '256MiB',
    cpu: 'gcf_gen1',
    retryCount: 0,
  },
  async () => {
    const count = await updateLeaderboard({ db });
    logger.info('승부예측 랭킹 갱신', { count });
  },
);

/**
 * Auth 계정이 지워지면(탈퇴) 그 사람의 데이터를 정리한다. 계정 삭제 이벤트는
 * 2세대 함수에 없어 1세대 트리거를 쓴다. 실패하면 다시 시도한다(정리는 몇 번
 * 돌아도 같은 결과다). 재시도는 최대 7일까지 이어지며 매번 과금되므로,
 * 하루가 지난 이벤트는 더 시도하지 않고 로그만 남긴다(운영자가 손으로 정리).
 */
const CLEANUP_RETRY_MS = 24 * 60 * 60 * 1000;
exports.cleanUpDeletedUser = functionsV1
  .region('asia-northeast3')
  .runWith({ failurePolicy: true, timeoutSeconds: 120, maxInstances: 5 })
  .auth.user()
  .onDelete(async (user, context) => {
    if (Date.now() - Date.parse(context.timestamp) > CLEANUP_RETRY_MS) {
      logger.error('탈퇴 데이터 정리 재시도 포기(하루 지남)', { uid: user.uid });
      return;
    }
    await cleanUpDeletedUser(db, admin.firestore.FieldValue, user.uid);
    logger.info('탈퇴 데이터 정리', { uid: user.uid });
  });
