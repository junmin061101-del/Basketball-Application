# 스토어 출시 빌드

## 1. Android 업로드 키 (한 번만)

Play 스토어는 debug 키로 서명된 번들을 받지 않는다. 업로드 키를 만들어
**저장소 밖**에 두고, 비밀번호와 함께 안전한 곳(비밀번호 관리자 등)에 백업한다.
잃어버리면 Play Console에서 키 재설정을 요청해야 한다.

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`basket_it/android/key.properties`를 만든다(.gitignore에 들어 있다):

```properties
storeFile=/home/<나>/upload-keystore.jks
storePassword=<위에서 정한 비밀번호>
keyAlias=upload
keyPassword=<위에서 정한 비밀번호>
```

key.properties가 없으면 release 빌드는 서명되지 않는다(잘못 서명된 번들이
올라가지 않게 일부러 그렇게 했다).

## 2. 빌드

```bash
cd basket_it
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols --strip
flutter build ipa --release --obfuscate --split-debug-info=build/symbols   # Mac
```

`build/symbols`는 버전마다 보관한다. 난독화된 크래시를 읽는 데 필요하다.
`--strip`을 빼면 앱 안에 디버그 정보(DWARF)가 남아 난독화가 반쯤 풀린다.

Codespace(메모리 8GB)에서는 Gradle이 중간에 꺼질 수 있어 `~/.gradle/gradle.properties`에
`org.gradle.jvmargs=-Xmx2560m -XX:MaxMetaspaceSize=768m`, `org.gradle.workers.max=1`,
`kotlin.compiler.execution.strategy=in-process`, `org.gradle.daemon=false`를 둔다(이 기기 전용).

## 3. Crashlytics 심볼 올리기

```bash
firebase crashlytics:symbols:upload --app=1:85596612349:android:97c6b0f7d6e0bc69cc0094 build/symbols
firebase crashlytics:symbols:upload --app=1:85596612349:ios:7e66d1bbb9521a82cc0094 build/symbols
```

iOS는 Xcode에서 dSYM 업로드 Run Script도 추가해야 한다(Mac 작업,
[Firebase 문서](https://firebase.google.com/docs/crashlytics/get-started?platform=flutter)).

## 4. App Check

앱은 휴대폰에서 App Check를 켠다(Android: Play Integrity, iOS: App Attest).
콘솔에서 **확인만** 하다가, 정상 요청 비율이 충분히 높아지면 **적용**을 켠다.

1. Firebase 콘솔 → App Check → Android 앱에 Play Integrity 등록
   (Play Console의 앱 서명 키 SHA-256 필요), iOS 앱에 App Attest 등록
2. debug 빌드는 실행할 때 로그에 찍히는 디버그 토큰을 콘솔에 등록한다
3. **웹 앱(basket-it-kbl.web.app)은 아직 App Check를 켜지 않았다.** Firestore에
   "적용"을 켜면 웹 사용자의 요청이 막힌다. 웹에 reCAPTCHA v3/Enterprise 키를
   받아 연결하기 전까지는 적용을 켜지 않는다.

## 5. 강제 업데이트

Firestore 콘솔에서 `appConfig/release` 문서를 만든다(앱은 읽기만 한다).

| 필드 | 값 |
| --- | --- |
| `minBuild` | 숫자. 이보다 낮은 빌드(pubspec `version`의 `+` 뒤)는 업데이트 화면으로 막는다. 처음엔 `1` |
| `message` | (선택) 업데이트 화면 안내 문구 |
| `androidUrl` | `https://play.google.com/store/apps/details?id=com.basketit.basket_it` |
| `iosUrl` | App Store 주소(출시 후 받는다) |

문서가 없거나 못 읽으면(오프라인) 막지 않는다. 웹은 보지 않는다.

## 6. 서버 배포

```bash
cd basket_it
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions:pushLiveScores,functions:updatePredictionLeaderboard,functions:cleanUpDeletedUser
cd functions && npm test && npm run test:rules   # 단위 테스트 + 규칙(에뮬레이터)
```

## 7. Mac(Xcode)에서 할 일

[LOCK_SCREEN_LIVE_SCORE.md](LOCK_SCREEN_LIVE_SCORE.md)의 위젯·Push 설정에 더해:

1. `ios/Runner/PrivacyInfo.xcprivacy`를 Runner 타깃에 추가(Add Files → Target: Runner)
2. Runner → Build Phases → Crashlytics dSYM 업로드 Run Script 추가
3. `cd ios && pod install` 후 실제 기기에서 release 빌드 확인(App Attest는 실기기만)

## 8. 스토어에 신고할 수집 데이터

| 데이터 | 용도 | 사용자와 연결 |
| --- | --- | --- |
| 이메일 | 로그인 | 예 |
| 사용자 ID(Firebase uid, 게스트 포함) | 계정·글쓴이 | 예 |
| 닉네임, 커뮤니티 글·댓글, 예측 토론, 승부예측 투표, 좋아요, 신고 | 앱 기능 | 예 |
| 팔로우한 팀·선수, 약관 동의 시각 | 앱 기능 | 예 |
| 기기 푸시 토큰(FCM, Live Activity) | 실시간 스코어 알림 | 아니요 |
| 크래시 기록(Crashlytics, 휴대폰만) | 오류 분석 | 아니요 |

광고·추적·위치·연락처·사진은 수집하지 않는다. 비밀번호는 Firebase Auth가 보관하며,
"아이디·비밀번호 저장"을 켜면 휴대폰 보안 저장소에만 남는다(웹은 이메일만).
탈퇴하면 서버(cleanUpDeletedUser)가 글쓴이 표시를 지우고 나머지를 삭제한다.
