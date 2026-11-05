'use strict';

/**
 * 탈퇴(Auth 계정 삭제) 뒤 그 사람의 데이터를 정리한다.
 *
 * 전에는 앱이 데이터를 지운 다음 계정을 지웠다. 그러면 마지막 계정 삭제가
 * "최근 로그인 필요"로 막혀도 데이터는 이미 지워져 있었고, 남의 글에 남은
 * 좋아요 uid와 신고 기록은 보안 규칙 때문에 앱이 손댈 수 없었다.
 * 이제 앱은 계정만 지우고, 이 함수가 Admin 권한으로 한 번에 정리한다.
 *
 * - 글·댓글·예측 토론: 지우지 않고 글쓴이만 "탈퇴한 사용자"로 (대화 맥락 유지)
 * - 승부예측 투표, users/{uid}(팔로우·닉네임·약관 동의): 삭제
 * - 남의 글 좋아요(likedBy)에서 빼고, 내가 낸 신고의 신고자 표시를 지운다
 */

const ANONYMOUS_UID = 'deleted';
const ANONYMOUS_NAME = '탈퇴한 사용자';
const PUBLIC_WRITINGS = ['communityPosts', 'communityComments', 'predictionComments'];

/** 문서 수백 개를 500개 단위(배치 한도)로 나눠 쓴다. */
async function inBatches(db, docs, apply) {
  for (let i = 0; i < docs.length; i += 500) {
    const batch = db.batch();
    for (const doc of docs.slice(i, i + 500)) apply(batch, doc);
    await batch.commit();
  }
}

async function cleanUpDeletedUser(db, FieldValue, uid) {
  if (!uid || uid === ANONYMOUS_UID) return;
  const mine = (collection, field = 'uid') =>
    db.collection(collection).where(field, '==', uid).get().then((s) => s.docs);

  for (const collection of PUBLIC_WRITINGS) {
    await inBatches(db, await mine(collection), (b, d) =>
      b.update(d.ref, { uid: ANONYMOUS_UID, displayName: ANONYMOUS_NAME }),
    );
  }
  await inBatches(db, await mine('predictionVotes'), (b, d) => b.delete(d.ref));

  const liked = await db.collection('communityPosts').where('likedBy', 'array-contains', uid).get();
  await inBatches(db, liked.docs, (b, d) =>
    b.update(d.ref, { likedBy: FieldValue.arrayRemove(uid) }),
  );
  await inBatches(db, await mine('reports', 'reporterUid'), (b, d) =>
    b.update(d.ref, { reporterUid: ANONYMOUS_UID }),
  );
  await db.collection('users').doc(uid).delete();
}

module.exports = { cleanUpDeletedUser, ANONYMOUS_UID, ANONYMOUS_NAME };
