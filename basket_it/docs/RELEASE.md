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
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
flutter build ipa --release --obfuscate --split-debug-info=build/symbols   # Mac
```

`build/symbols`는 버전마다 보관한다. 난독화된 크래시를 읽는 데 필요하다.

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
