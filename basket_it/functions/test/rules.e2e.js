/**
 * 보안 규칙(firestore.rules)과 탈퇴 정리(account-cleanup.js)를 에뮬레이터에서 확인한다.
 *   npm run test:rules
 */
'use strict';

const fs = require('fs');
const path = require('path');
const test = require('node:test');
const assert = require('node:assert');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, setDoc, updateDoc, addDoc, collection, serverTimestamp, arrayUnion, increment, getDoc,
} = require('firebase/firestore');

const PROJECT = 'demo-basket';
let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8') },
  });
});
test.after(() => env.cleanup());
test.beforeEach(() => env.clearFirestore());

const as = (uid) => env.authenticatedContext(uid).firestore();
const post = (over = {}) => ({
  uid: 'alice', displayName: '앨리스', category: 'free', league: 'kbl', title: '제목', body: '본문',
  commentCount: 0, likedBy: [], createdAt: serverTimestamp(), ...over,
});
const seedPost = (data = {}) => env.withSecurityRulesDisabled((c) =>
  setDoc(doc(c.firestore(), 'communityPosts/p1'), { ...post(), createdAt: new Date(), ...data }));

test('글: 정상 글은 되고, 좋아요·댓글 수를 채워 넣거나 시각을 지어내면 막힌다', async () => {
  const db = as('alice');
  await assertSucceeds(addDoc(collection(db, 'communityPosts'), post()));
  await assertFails(addDoc(collection(db, 'communityPosts'), post({ likedBy: ['x', 'y'] })));
  await assertFails(addDoc(collection(db, 'communityPosts'), post({ commentCount: 99 })));
  await assertFails(addDoc(collection(db, 'communityPosts'), post({ createdAt: new Date(2100, 0, 1) })));
  await assertFails(addDoc(collection(db, 'communityPosts'), post({ pinned: true })));
  await assertFails(addDoc(collection(db, 'communityPosts'), post({ uid: 'bob' })));
});

test('좋아요: 내 uid 하나만 넣고 뺄 수 있다', async () => {
  await seedPost({ likedBy: ['carol'] });
  const bob = as('bob');
  await assertSucceeds(updateDoc(doc(bob, 'communityPosts/p1'), { likedBy: arrayUnion('bob') }));
  await assertFails(updateDoc(doc(bob, 'communityPosts/p1'), { likedBy: ['bob'] })); // carol을 지움
  await assertFails(updateDoc(doc(bob, 'communityPosts/p1'), { likedBy: arrayUnion('fake') }));
  await assertFails(updateDoc(doc(bob, 'communityPosts/p1'), { title: '남의 글 고치기' }));
  await assertFails(updateDoc(doc(as('alice'), 'communityPosts/p1'), { uid: 'bob' })); // 작성자 바꾸기
});

test('댓글 수는 1씩만 바뀐다', async () => {
  await seedPost({ commentCount: 3 });
  const bob = as('bob');
  await assertSucceeds(updateDoc(doc(bob, 'communityPosts/p1'), { commentCount: increment(1) }));
  await assertSucceeds(updateDoc(doc(bob, 'communityPosts/p1'), { commentCount: increment(-1) }));
  await assertFails(updateDoc(doc(bob, 'communityPosts/p1'), { commentCount: 999 }));
});

test('댓글: 있는 글에만, 서버 시각으로만 단다', async () => {
  await seedPost();
  const bob = as('bob');
  const c = (over = {}) => ({ postId: 'p1', uid: 'bob', displayName: '밥', text: '좋아요', createdAt: serverTimestamp(), ...over });
  await assertSucceeds(addDoc(collection(bob, 'communityComments'), c()));
  await assertFails(addDoc(collection(bob, 'communityComments'), c({ postId: 'nope' })));
  await assertFails(addDoc(collection(bob, 'communityComments'), c({ createdAt: new Date() })));
});

test('승부예측 투표: 서버 시각·정해진 값만, 랭킹은 읽기만', async () => {
  const bob = as('bob');
  const v = (over = {}) => ({ gameId: 'g1', uid: 'bob', displayName: '밥', pick: 'home', gameDate: '2026-11-05', createdAt: serverTimestamp(), ...over });
  await assertSucceeds(setDoc(doc(bob, 'predictionVotes/g1_bob'), v()));
  await assertFails(setDoc(doc(bob, 'predictionVotes/g1_bob'), v({ createdAt: new Date(2000, 0, 1) })));
  await assertFails(setDoc(doc(bob, 'predictionVotes/g1_bob'), v({ pick: 'draw' })));
  await assertFails(setDoc(doc(bob, 'leaderboard/kbl'), { entries: [] }));
  await assertSucceeds(getDoc(doc(bob, 'leaderboard/kbl')));
});

test('강제 업데이트 설정은 로그인 전에도 읽고, 아무도 쓰지 못한다', async () => {
  const guest = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(guest, 'appConfig/release')));
  await assertFails(setDoc(doc(as('bob'), 'appConfig/release'), { minBuild: 0 }));
});

test('탈퇴 정리: 글은 비식별, 투표·사용자 문서는 삭제, 남의 글 좋아요와 신고자 표시도 지운다', async () => {
  process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8080';
  const admin = require('firebase-admin');
  if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT });
  const db = admin.firestore();
  const { cleanUpDeletedUser } = require('../account-cleanup');

  await db.doc('communityPosts/mine').set({ uid: 'bob', displayName: '밥', likedBy: [] });
  await db.doc('communityPosts/other').set({ uid: 'alice', displayName: '앨리스', likedBy: ['bob', 'carol'] });
  await db.doc('communityComments/c1').set({ uid: 'bob', displayName: '밥', postId: 'other' });
  await db.doc('predictionVotes/g1_bob').set({ uid: 'bob', gameId: 'g1' });
  await db.doc('reports/x_bob').set({ reporterUid: 'bob', targetId: 'x' });
  await db.doc('users/bob').set({ nickname: '밥' });

  await cleanUpDeletedUser(db, admin.firestore.FieldValue, 'bob');

  assert.deepStrictEqual(
    (await db.doc('communityPosts/mine').get()).data(),
    { uid: 'deleted', displayName: '탈퇴한 사용자', likedBy: [] },
  );
  assert.deepStrictEqual((await db.doc('communityPosts/other').get()).data().likedBy, ['carol']);
  assert.strictEqual((await db.doc('communityComments/c1').get()).data().uid, 'deleted');
  assert.strictEqual((await db.doc('predictionVotes/g1_bob').get()).exists, false);
  assert.strictEqual((await db.doc('reports/x_bob').get()).data().reporterUid, 'deleted');
  assert.strictEqual((await db.doc('users/bob').get()).exists, false);
});
