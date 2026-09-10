# Basket it 뉴스 백엔드

앱 홈 탭의 기사는 전부 이 함수에서 나온다. 네이버 뉴스 검색 API로 KBL·해외파
농구 기사를 모아, 앱이 그대로 그릴 수 있는 형태로 돌려준다.

| 파일 | 역할 |
| --- | --- |
| `index.js` | `getBasketballNews`(앱 호출), `refreshBasketballNews`(10분마다 캐시 예열) |
| `news-source.js` | 매체 화이트리스트, 검색어, 태그 제거·팀 매칭·중복 제거 같은 순수 로직 |
| `test/news-source.test.js` | 위 로직 단위 테스트 (`npm test`) |

## 응답 형태

```json
{
  "category": "all",
  "articles": [
    {
      "category": "kbl",
      "team": "서울 SK",
      "team_id": "sk",
      "source": "점프볼",
      "pub_date": "2026-09-08T01:00:00.000Z",
      "title": "서울 SK, 창원 LG 꺾고 4연승",
      "description": "리바운드를 장악하며 승리했다.",
      "article_url": "https://jumpball.co.kr/news/1",
      "thumbnail_url": "https://jumpball.co.kr/img/1.jpg"
    }
  ]
}
```

요청은 `{ "category": "kbl" | "overseas" | "all", "sort": "date" | "sim" }`.
`all`은 두 쪽을 모두 모아 `pub_date` 최신순으로 합친다. `sort`는 생략하면
`date`(최신순)이고, `sim`은 정확도순이다. 정렬이 다르면 캐시도 따로 둔다.

호출하는 네이버 엔드포인트는 다음 하나뿐이다.

```
GET https://naverapihub.apigw.ntruss.com/search/v1/news?query=<검색어>&display=20&sort=date
헤더: X-NCP-APIGW-API-KEY-ID, X-NCP-APIGW-API-KEY
```

`query`는 `URLSearchParams`로 만들어 인코딩까지 함께 처리한다.

## 배포에 필요한 것

### 1. Blaze(종량제) 요금제

Cloud Functions는 무료 Spark 요금제에서 배포할 수 없다. 콘솔에서 결제 계정을
연결한다 → https://console.firebase.google.com/project/basket-it-kbl/usage/details

이 앱 규모(10분마다 예열 + 사용자 호출)는 Blaze 무료 할당량 안에서 거의
비용이 발생하지 않지만, 예산 알림을 걸어두는 편이 안전하다.

### 2. NAVER API HUB 자격증명

https://www.ncloud.com 콘솔 → NAVER API HUB → 검색 API 이용 신청 후
"인증 정보 → Application key"에서 Client ID / Client Secret을 받는다.
(developers.naver.com의 구 검색 API는 API HUB로 이관됐다. 자세한 차이는
[../NEWS.md](../NEWS.md) 참고)

값은 코드에 절대 넣지 않고 `functions/.env`에만 둔다. 이 파일은
`.gitignore`에 있어 저장소에 올라가지 않고, `firebase deploy`가 읽어서 함수의
환경변수로 주입한다. 코드는 `process.env.NAVER_CLIENT_ID` /
`process.env.NAVER_CLIENT_SECRET`로만 읽으며, 값 자체는 어떤 로그에도 남기지
않는다(빠졌을 때 어느 키가 없는지만 남긴다).

```bash
cp functions/.env.example functions/.env   # 값을 채운다
```

더 엄격하게 가려면 Secret Manager로 옮길 수 있다. 이때는 `index.js`에서
`defineSecret`을 쓰고 각 함수 옵션에 `secrets: [...]`를 추가해야 한다.

```bash
firebase functions:secrets:set NAVER_CLIENT_ID
firebase functions:secrets:set NAVER_CLIENT_SECRET
```

#### 자격증명이 틀렸을 때

| 응답 | 뜻 |
| --- | --- |
| `300 / Not Found Exception` | 경로가 틀렸다. `/search/v1/news`가 맞다 |
| `Not Exist Client ID` | 인증 헤더 이름이 틀렸다(구 `X-Naver-Client-*`를 보냈다) |
| `NID AUTH Result Invalid (1000)` | 구 엔드포인트에 API HUB 키를 보냈다 |
| `401` + API HUB 오류 | 키가 틀렸거나 검색 API 이용 신청이 안 돼 있다 |

빠르게 확인하려면:

```bash
curl -s -H "X-NCP-APIGW-API-KEY-ID: $NAVER_CLIENT_ID" \
     -H "X-NCP-APIGW-API-KEY: $NAVER_CLIENT_SECRET" \
     "https://naverapihub.apigw.ntruss.com/search/v1/news?query=KBL&display=1"
```

### 3. 배포

```bash
cd basket_it
firebase deploy --only functions
```

리전은 `asia-northeast3`(서울)이며, 앱 쪽
`FunctionsNewsRepository.region`과 반드시 같아야 한다.

## 운영 중 조정

검색어는 Firestore `config/news` 문서로 덮어쓸 수 있다(재배포 불필요).

```
config/news {
  kblQueries: ["KBL", "프로농구", ...],
  overseasQueries: ["이현중 농구", ...]
}
```

매체 화이트리스트는 `news-source.js`의 `SOURCE_BY_DOMAIN`에 있다. 처음에는
넉넉하게 열어두었으니, 운영하며 원치 않는 매체가 보이면 여기서 뺀다.

## 테스트

```bash
cd functions
npm test              # 태그 제거·화이트리스트·팀 매칭·중복 제거 단위 테스트
npm run test:pipeline # Firestore 에뮬레이터 + fetch 스텁으로 전체 파이프라인 검증
```

`test:pipeline`은 네이버 자격증명 없이도 돌아간다. 검색 호출만 스텁으로 막고
나머지(헤더/파라미터 전달, 태그 제거, 팀 매칭, originallink 폴백, 화이트리스트
필터, og:image 추출, 뉴스·이미지 캐시, 정렬, 잘못된 인자 거부)는 실제 코드와
실제 Firestore로 확인한다.

## 캐시

- `newsCache/{category}` — 카테고리별 최근 응답. TTL 5분.
- `newsImageCache/{base64url(article_url)}` — 기사별 og:image. 한 번 확인한
  기사는 다시 긁지 않는다(이미지가 없던 기사도 기록해 재요청을 막는다).

두 컬렉션 모두 보안 규칙에서 클라이언트 접근을 막아두었다. 서버(Admin SDK)만
읽고 쓴다.
