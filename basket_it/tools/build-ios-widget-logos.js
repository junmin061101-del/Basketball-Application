'use strict';

/**
 * iPhone 잠금화면 스코어 위젯(ios/LiveScoreWidget)에 넣을 팀 로고를 만든다.
 * 위젯은 네트워크 이미지를 못 그리므로 로고를 확장 안에 넣어야 한다.
 *
 * - NBA: 수집기가 올린 nba/teams.json의 ESPN 공식 로고를 128px로 받는다.
 * - KBL: 앱에 이미 넣은 공식 아이콘(assets/logos/kbl)을 그대로 쓴다.
 *
 * 사용: node tools/build-ios-widget-logos.js
 * 결과: ios/LiveScoreWidget/Assets.xcassets/{nba_13,kbl_sk,...}.imageset
 */

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const OUT = path.join(ROOT, 'ios/LiveScoreWidget/Assets.xcassets');
const TEAMS_URL = 'https://junmin061101-del.github.io/Basketball-Application/nba/teams.json';

function writeImageSet(name, bytes) {
  const dir = path.join(OUT, `${name}.imageset`);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, `${name}.png`), bytes);
  fs.writeFileSync(
    path.join(dir, 'Contents.json'),
    `${JSON.stringify({ images: [{ filename: `${name}.png`, idiom: 'universal' }], info: { author: 'xcode', version: 1 } }, null, 2)}\n`,
  );
}

/** ESPN 이미지 리사이저(combiner)로 작게 받고, 안 되면 원본을 받는다. */
async function fetchLogo(url) {
  const pathname = new URL(url).pathname;
  const candidates = [`https://a.espncdn.com/combiner/i?img=${pathname}&w=128&h=128`, url];
  for (const candidate of candidates) {
    const res = await fetch(candidate, { signal: AbortSignal.timeout(15000) });
    const type = res.headers.get('content-type') ?? '';
    if (res.ok && type.startsWith('image/png')) return Buffer.from(await res.arrayBuffer());
  }
  throw new Error(`로고를 받지 못했습니다: ${url}`);
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, 'Contents.json'), `${JSON.stringify({ info: { author: 'xcode', version: 1 } }, null, 2)}\n`);

  const res = await fetch(TEAMS_URL, { signal: AbortSignal.timeout(15000) });
  if (!res.ok) throw new Error(`HTTP ${res.status} ${TEAMS_URL}`);
  const { teams } = await res.json();
  for (const team of teams) {
    writeImageSet(`nba_${team.id}`, await fetchLogo(team.logo));
  }

  const kblDir = path.join(ROOT, 'assets/logos/kbl');
  const kbl = fs.readdirSync(kblDir).filter((f) => f.endsWith('.png'));
  for (const file of kbl) {
    writeImageSet(`kbl_${path.basename(file, '.png')}`, fs.readFileSync(path.join(kblDir, file)));
  }
  console.log(`NBA ${teams.length}개, KBL ${kbl.length}개 로고를 만들었습니다 → ${path.relative(ROOT, OUT)}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
