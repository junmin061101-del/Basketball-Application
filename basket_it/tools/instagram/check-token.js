#!/usr/bin/env node
'use strict';

/**
 * 인스타 게시 토큰(IG_ACCESS_TOKEN)이 동작하는지, 어느 인스타 계정에 닿는지 확인한다.
 * 조회만 하고 아무것도 게시하지 않는다. 토큰 값은 출력하지 않는다.
 *
 * 시스템 사용자 토큰(비즈니스 통합 로그인)은 연결 방식에 따라 계정 ID를 찾는 길이
 * 달라서, 알려진 길을 차례로 시도해 결과를 모두 보여준다.
 */

const token = process.env.IG_ACCESS_TOKEN;
if (!token) {
  console.error('IG_ACCESS_TOKEN이 없어요');
  process.exit(1);
}

async function get(label, url) {
  try {
    const res = await fetch(`${url}${url.includes('?') ? '&' : '?'}access_token=${encodeURIComponent(token)}`, {
      signal: AbortSignal.timeout(15000),
    });
    const body = await res.json().catch(() => ({}));
    const shown = JSON.stringify(body, (k, v) => (k === 'access_token' ? '[숨김]' : v));
    console.log(`\n[${label}] HTTP ${res.status}\n${shown.slice(0, 1500)}`);
    return res.ok ? body : null;
  } catch (e) {
    console.log(`\n[${label}] 실패: ${e.message}`);
    return null;
  }
}

(async () => {
  const me = await get('토큰 주인', 'https://graph.facebook.com/me?fields=id,name');
  await get('토큰 권한', 'https://graph.facebook.com/me/permissions');
  await get('페이지 연결 인스타', 'https://graph.facebook.com/me/accounts?fields=name,instagram_business_account{id,username}');
  await get('인스타 로그인 방식', 'https://graph.instagram.com/me?fields=user_id,username,account_type');
  if (me?.id) {
    await get('할당된 인스타 계정', `https://graph.facebook.com/${me.id}/assigned_business_asset_groups`);
    await get('시스템 사용자 비즈니스', `https://graph.facebook.com/${me.id}?fields=business{id,name}`);
  }
})();
