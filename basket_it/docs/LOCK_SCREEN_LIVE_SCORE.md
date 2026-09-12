# 잠금화면 실시간 스코어

팔로우한 팀의 경기가 진행 중이면, 앱을 열지 않아도 잠금화면에
**팀 로고 · 점수 · 쿼터 · 남은 시간**이 뜹니다.

| | Android | iPhone |
|---|---|---|
| 모양 | 잠금화면·알림창의 고정 알림(밀어도 안 지워짐) | Live Activity(잠금화면 + 다이내믹 아일랜드) |
| 갱신 | 서버 푸시(FCM 데이터 메시지) | 서버 푸시(FCM → APNs Live Activity) |
| 경기 시작 시 | 첫 푸시에 알림이 생김 | iOS 17.2+에서 서버가 자동으로 띄움 |
| 경기 종료 | 최종 점수를 15분 보여준 뒤 사라짐 | 같음 |

## 동작 방식

```
[Cloud Functions: pushLiveScores, 1분마다]
  ├─ ESPN 스코어보드(NBA) · KBL 일정/문자중계에서 진행 중 경기 확인
  │    └─ 진행 중 경기가 없으면 바로 종료 (비용 거의 0)
  ├─ Firestore liveGames/{경기키} 와 비교해 점수·쿼터·시간이 바뀐 경기만 고름
  ├─ liveSubscribers 에서 그 팀을 팔로우한 기기를 찾음
  └─ FCM 전송 (진행 중이면 30초 뒤 한 번 더 → 약 30초 간격 갱신)

[앱]
  로그인 후 메인 화면에서 FCM 토큰 + 팔로우 팀을 liveSubscribers/{토큰} 에 저장
  (iPhone은 Live Activity 시작/갱신 토큰도 함께 저장)
```

- 서버 로직: `functions/live-score.js` (테스트: `functions/test/live-score.test.js`)
- 앱 구독 동기화: `lib/services/live_score_push.dart`
- Android 알림: `android/app/src/main/kotlin/.../LiveScoreActivityManager.kt`, `res/layout/live_score_notification.xml`
- iPhone 위젯: `ios/LiveScoreWidget/`
- 보안 규칙: `firestore.rules` 의 `liveSubscribers`, `liveGames` (토큰은 서버만 읽음)

## 1. Firebase (공통, 꼭 필요)

1. Firebase 콘솔 → 프로젝트 `basket-it-kbl` → 요금제를 **Blaze**로 변경
   - 예약 함수(Cloud Scheduler)는 Blaze에서만 동작합니다.
   - 경기가 없을 때는 1분마다 몇 초만 돌고 끝나서 무료 사용량 안에서 대부분 해결됩니다.
     (Cloud Scheduler 작업 3개까지 무료, 함수 호출 월 200만 회 무료)
2. 배포
   ```bash
   cd basket_it
   firebase deploy --only functions:pushLiveScores,firestore:rules
   ```

## 2. Android

추가 설정 없이 동작합니다. 앱을 처음 열면 **알림 허용**을 물어보며, 허용해야 잠금화면에 뜹니다.
휴대폰 설정 → 알림 → Basket it → "실시간 경기 스코어" 채널에서 잠금화면 표시를 켜 둘 수 있습니다.

## 3. iPhone (Mac + Apple Developer 계정 필요)

Live Activity는 Xcode에서 위젯 확장 타깃을 추가해야 해서, 한 번은 Mac에서 설정해야 합니다.

1. **APNs 키를 Firebase에 등록**
   - developer.apple.com → Certificates, IDs & Profiles → Keys → `+` → *Apple Push Notifications service (APNs)* 체크 → `.p8` 다운로드
   - Firebase 콘솔 → 프로젝트 설정 → 클라우드 메시징 → Apple 앱 구성 → APNs 인증 키 업로드(키 ID, 팀 ID 입력)
2. **iOS 앱을 Firebase에 추가**하고 `GoogleService-Info.plist`를 `ios/Runner/`에 넣기
   (또는 `flutterfire configure` 실행)
3. `open ios/Runner.xcworkspace` 로 Xcode 열기
4. **Runner 타깃** → Signing & Capabilities
   - `+ Capability` → **Push Notifications**
   - `+ Capability` → **Background Modes** → *Remote notifications* 체크
   - `+ Capability` → **App Groups** → `group.com.basketit.basketIt.liveScore` 추가
5. **위젯 확장 추가**: File → New → Target → **Widget Extension**
   - Product Name: `LiveScoreWidget`, *Include Live Activity* 체크, *Include Configuration App Intent* 해제
   - "Activate scheme?" → Activate
   - Xcode가 만든 `LiveScoreWidget` 폴더 안의 Swift 파일·Info.plist·Assets.xcassets를 지우고,
     저장소의 `ios/LiveScoreWidget/` 파일들(`LiveScoreWidgetBundle.swift`, `LiveScoreLiveActivity.swift`,
     `Info.plist`, `Assets.xcassets`)을 타깃에 추가(Add Files → Target: LiveScoreWidget)
   - LiveScoreWidget 타깃 → General → Minimum Deployments: **iOS 16.1** 이상
   - LiveScoreWidget 타깃 → Signing & Capabilities → **App Groups**에 같은 그룹 추가
6. `Runner` 타깃 → Build Phases에서 *Embed Foundation Extensions*가 *Thin Binary* 보다 위에 있는지 확인
   (Flutter 프로젝트에서 "Cycle inside Runner" 빌드 오류가 나면 이 순서를 바꿉니다)
7. 실제 아이폰으로 실행 (시뮬레이터는 푸시를 받지 못합니다)

`Info.plist`의 `NSSupportsLiveActivities`, `NSSupportsLiveActivitiesFrequentUpdates`는 이미 켜 두었습니다.

### 참고

- 경기 시작 시 서버가 Live Activity를 자동으로 띄우는 기능(push-to-start)은 **iOS 17.2 이상**에서 됩니다.
- 사용자가 설정 → Basket it → **실시간 현황**을 끄면 뜨지 않습니다.
- 팀 로고를 새로 받아야 하면: `node tools/build-ios-widget-logos.js`

## 확인 방법

경기가 없는 날에도 흐름을 확인하려면 Firebase 콘솔 → Functions → `pushLiveScores` 로그를 봅니다.
진행 중 경기가 있거나 푸시를 보냈을 때만 `실시간 스코어 푸시` 로그가 남습니다.
