# Baskit 예약 함수

| 파일 | 역할 |
| --- | --- |
| `index.js` | 함수 목록: `pushLiveScores`(1분마다), `updatePredictionLeaderboard`(30분마다) |
| `live-score.js` | 진행 중인 경기 점수를 잠금화면(Android 알림·iPhone Live Activity)으로 보낸다 |
| `leaderboard.js` | 승부예측 랭킹 채점. 마감(경기 1시간 전) 뒤 투표는 세지 않는다 |
| `news-source.js` | 뉴스 수집 순수 로직. GitHub Actions 수집기(`tools/fetch-news.js`)가 쓴다 |

외부 비밀 키를 쓰는 함수는 없다. 뉴스용 네이버 키는 GitHub Actions 비밀값에만 있다.

```bash
npm test                                                        # 단위 테스트
firebase deploy --only functions:pushLiveScores,functions:updatePredictionLeaderboard
```
