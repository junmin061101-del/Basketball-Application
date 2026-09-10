# 뉴스 기능 구성

홈 탭 기사는 네이버 뉴스 검색 API에서 온다. Client ID/Secret이 앱에 들어가면
누구나 꺼내 쓸 수 있으므로, 검색은 항상 서버에서 하고 앱은 결과만 읽는다.

현재는 **무료 요금제로 운영되는 구성**을 쓴다.

```
GitHub Actions (20분마다)          GitHub Pages              앱
  네이버 검색 API 호출     ──▶   news/all.json       ──▶   홈 탭
  태그 제거·팀 매칭·중복 제거      news/kbl.json             (5분마다 확인)
  og:image 추출                   news/overseas.json
       ▲
  Secret은 GitHub Secrets에만
```

| | 파일 |
| --- | --- |
| 수집 스크립트 | [tools/fetch-news.js](tools/fetch-news.js) |
| 수집 로직(공용) | [functions/news-source.js](functions/news-source.js) |
| 워크플로 | [../.github/workflows/news.yml](../.github/workflows/news.yml) |
| 앱 Repository | [lib/data/repositories/news_repository.dart](lib/data/repositories/news_repository.dart) |

## 준비 절차

### 1. NAVER API HUB 키 발급

**https://www.ncloud.com** 콘솔 → **NAVER API HUB** → 검색 API 이용 신청.
"인증 정보 → Application key"의 Client ID / Client Secret을 쓴다.

기존 `developers.naver.com`의 검색 API(`openapi.naver.com`)는 **NAVER API
HUB로 이관**됐다. 도메인·경로·인증 헤더가 모두 바뀌었다.

| | 기존 (이관 전) | 현재 (API HUB) |
| --- | --- | --- |
| 도메인 | `openapi.naver.com` | `naverapihub.apigw.ntruss.com` |
| 경로 | `/v1/search/news.json` | `/search/v1/news` |
| 인증 헤더 | `X-Naver-Client-Id`<br>`X-Naver-Client-Secret` | `X-NCP-APIGW-API-KEY-ID`<br>`X-NCP-APIGW-API-KEY` |
| 오류 형태 | `{errorCode, errorMessage}` | `{error:{errorCode, message, details}}` |

응답 필드(`title`, `originallink`, `link`, `description`, `pubDate`)와 요청
파라미터(`query`, `display`, `sort`)는 그대로다.

지금 구성은 20분마다 20회씩, 하루 1,440회 정도를 쓴다.

### 2. GitHub Secrets 등록

저장소 **Settings → Secrets and variables → Actions**:

| 이름 | 값 |
| --- | --- |
| `NAVER_CLIENT_ID` | API HUB Client ID |
| `NAVER_CLIENT_SECRET` | API HUB Client Secret |

CLI로도 된다.

```bash
gh secret set NAVER_CLIENT_ID
gh secret set NAVER_CLIENT_SECRET
```

### 3. GitHub Pages 켜기

저장소 **Settings → Pages → Source**를 **"GitHub Actions"** 로 바꾼다.

### 4. 첫 실행

워크플로를 푸시하면 자동으로 한 번 돌고, 이후 20분마다 반복한다. 수동
실행은 Actions 탭의 "뉴스 수집" → Run workflow.

결과는 `https://<계정>.github.io/<저장소>/news/all.json`에서 바로 확인할 수 있다.

## 주의할 점

- **공개 저장소의 예약 워크플로는 60일간 저장소 활동이 없으면 자동으로 멈춘다.**
  멈추면 Actions 탭에서 다시 켜면 된다.
- 수집이 **전부 실패하면 파일을 쓰지 않고 중단**한다. 멀쩡히 올라가 있던
  뉴스를 빈 파일로 덮어쓰지 않기 위해서다.
- 앱은 뉴스를 못 읽으면 "실제 기사가 아니에요" 안내와 함께 샘플을 보여준다.
  수집이 정상화되면 다음 확인 때 실제 기사로 교체된다.
- **일반 매체 기사는 제목에 농구 신호가 있어야 통과한다.** 본문까지 보면
  "NBA 농구장으로 쓰이는 경기장에서 열린 전당대회" 같은 스치는 언급 때문에
  정치·연예 기사가 섞여 들어온다. 대신 농구만 다루는 매체(점프볼,
  바스켓코리아, 루키, KBL)는 제목이 밋밋한 이적 기사도 받아준다.
  판단 기준은 `news-source.js`의 `looksLikeBasketball`에 있다.

## 실시간이 필요해지면

[functions/](functions/)에 Cloud Functions 버전(`getBasketballNews`)이 이미
완성돼 있다. 호출할 때마다 실시간으로 검색한다. 다만 Cloud Functions는
Firebase **Blaze(종량제)** 요금제에서만 배포된다. 자세한 건
[functions/README.md](functions/README.md).

바꾸려면 [lib/providers/news_providers.dart](lib/providers/news_providers.dart)의
주입 지점 한 줄만 고치면 된다.

```dart
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  return FunctionsNewsRepository(); // StaticJsonNewsRepository() 대신
});
```

폴링 주기(`newsPollInterval`)도 90초 정도로 줄이면 된다.

## 테스트

```bash
flutter test                          # 앱 (파싱·카드 리스트·클릭·필터)
cd functions && npm test              # 수집 로직 단위 테스트
cd functions && npm run test:pipeline # Cloud Functions 전체 파이프라인
```
