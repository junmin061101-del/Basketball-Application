'use strict';
// node --test tools/instagram/headlines.test.js
const test = require('node:test');
const assert = require('node:assert');
const { topStory } = require('./headlines');

test('가장 많은 언론사가 다룬 소식을 헤드라인으로 고른다', () => {
  const now = Date.parse('2026-11-19T12:00:00Z');
  const at = (h) => new Date(now - h * 3600e3).toISOString();
  const a = (source, title, h) => ({ source, title, pub_date: at(h) });
  const story = topStory([
    a('루키', '돈치치 41점, 레이커스 9연승', 1), // 한 곳만, 가장 최근
    a('뉴스1', "'브런슨 31점' 뉴욕, 보스턴 꺾고 3연승", 3),
    a('SBS', '브런슨 31점 폭발…뉴욕 3연승 질주', 4),
    a('연합뉴스', '뉴욕 브런슨 31점, 3연승', 5),
    a('점프볼', '[사진] 오늘의 코트', 30), // 하루 지난 기사는 빠진다
  ], now);
  assert.deepStrictEqual(story.map((s) => s.source), ['뉴스1', 'SBS', '연합뉴스']);
});
