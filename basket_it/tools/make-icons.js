#!/usr/bin/env node
'use strict';

/**
 * 앱 아이콘을 한 원본(assets/brand/mark.svg)에서 모두 만든다.
 *
 *   node tools/make-icons.js
 *
 * - Android: ic_launcher.png(둥근 사각형, 옛 런처) + 적응형 아이콘 전경(Android 8+,
 *   런처가 원·물방울로 잘라도 남게 가운데 안전 영역 안에 둔다. 배경은 흰색)
 * - iOS: AppIcon 전부(흰 정사각형, 투명 없음. 모서리는 iOS가 깎는다)
 * - 웹: 아이콘·마스커블·애플 터치·파비콘
 * - assets/brand: 인스타 프로필(1080, 원으로 잘려도 남게) · 확인용 앱 아이콘 ·
 *   앱 안 로고(app-logo.png, 로딩 화면 등)
 * - 실행 화면(앱을 누른 직후): Android launch_logo, iOS LaunchImage
 *
 * 로고를 바꾸면 mark.svg만 고치고 이 스크립트를 다시 돌린다. 그림은 Playwright로 찍는다
 * (tools/instagram에 깔린 것을 쓴다).
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require(path.join(__dirname, 'instagram', 'node_modules', 'playwright'));

const ROOT = path.join(__dirname, '..');
const mark = fs.readFileSync(path.join(ROOT, 'assets/brand/mark.svg'), 'utf8');
const art = mark.replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');

/** 512 캔버스에 로고를 scale배로 가운데 둔 SVG. bg: 'square' | 'rounded' | null(투명). */
function icon(scale, bg) {
  const back = bg === 'square' ? '<rect width="512" height="512" fill="#fff"/>' : bg === 'rounded' ? '<rect width="512" height="512" rx="112" fill="#fff"/>' : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">${back}<g transform="translate(256 256) scale(${scale}) translate(-515 -545)">${art}</g></svg>`;
}

// 로고 크기(512 캔버스 기준 배율). 원본 앱 아이콘 비율에 맞췄다.
const FULL = icon(0.43, 'square'); // iOS·웹(가장자리까지 흰색)
const ROUNDED = icon(0.43, 'rounded'); // Android 옛 런처
const MASKABLE = icon(0.33, 'square'); // 웹 마스커블(가운데 80% 안)
const FOREGROUND = icon(0.27, null); // Android 적응형 전경(가운데 66/108 원 안)
const PROFILE = icon(0.4, 'square'); // 인스타 프로필(원으로 잘림)

const ANDROID = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

async function main() {
  const jobs = [];
  const res = (...p) => path.join(ROOT, 'android/app/src/main/res', ...p);
  for (const [d, k] of Object.entries(ANDROID)) {
    jobs.push([ROUNDED, 48 * k, res(`mipmap-${d}`, 'ic_launcher.png'), true]);
    jobs.push([FOREGROUND, 108 * k, res(`drawable-${d}`, 'ic_launcher_foreground.png'), true]);
    jobs.push([ROUNDED, 120 * k, res(`drawable-${d}`, 'launch_logo.png'), true]);
  }
  const ios = path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
  for (const f of fs.readdirSync(ios).filter((x) => x.endsWith('.png'))) {
    const [, size, mul] = f.match(/(\d+(?:\.\d+)?)x[\d.]+@(\d)x/);
    jobs.push([FULL, Math.round(size * mul), path.join(ios, f), false]);
  }
  const launch = path.join(ROOT, 'ios/Runner/Assets.xcassets/LaunchImage.imageset');
  for (const k of [1, 2, 3]) jobs.push([ROUNDED, 120 * k, path.join(launch, `LaunchImage${k > 1 ? `@${k}x` : ''}.png`), true]);
  const web = (...p) => path.join(ROOT, 'web', ...p);
  jobs.push(
    [FULL, 192, web('icons/Icon-192.png'), false],
    [FULL, 512, web('icons/Icon-512.png'), false],
    [MASKABLE, 192, web('icons/Icon-maskable-192.png'), false],
    [MASKABLE, 512, web('icons/Icon-maskable-512.png'), false],
    [FULL, 180, web('icons/apple-touch-icon.png'), false],
    [FULL, 32, web('favicon.png'), false],
    [FULL, 48, web('favicon-48.png'), false],
    [FULL, 96, web('favicon-96.png'), false],
    [PROFILE, 1080, path.join(ROOT, 'assets/brand/profile-1080.png'), false],
    [ROUNDED, 1080, path.join(ROOT, 'assets/brand/app-icon-1080.png'), true],
    [ROUNDED, 360, path.join(ROOT, 'assets/brand/app-logo.png'), true],
  );

  const browser = await chromium.launch();
  const page = await browser.newPage();
  for (const [svg, px, out, transparent] of jobs) {
    await page.setViewportSize({ width: px, height: px });
    await page.setContent(`<style>body{margin:0}svg{display:block}</style>${svg.replace('<svg ', `<svg width="${px}" height="${px}" `)}`);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    await page.screenshot({ path: out, omitBackground: transparent });
    console.log(`${px}px ${path.relative(ROOT, out)}`);
  }
  await browser.close();
}

main().catch((e) => {
  console.error('실패:', e.message);
  process.exit(1);
});
