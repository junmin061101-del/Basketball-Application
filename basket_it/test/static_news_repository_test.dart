import 'dart:convert';

import 'package:basket_it/data/models/news_article.dart';
import 'package:basket_it/data/repositories/news_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const base = 'https://example.github.io/app/news';

Map<String, Object?> payload(String category) => {
  'category': category,
  'generated_at': '2026-09-10T00:00:00.000Z',
  'articles': [
    {
      'category': 'kbl',
      'team': '서울 SK',
      'team_id': 'sk',
      'source': '점프볼',
      'pub_date': '2026-09-09T12:30:00.000Z',
      'title': '서울 SK, 창원 LG 꺾고 4연승',
      'description': '리바운드를 장악했다.',
      'article_url': 'https://jumpball.co.kr/news/1',
      'thumbnail_url': 'https://jumpball.co.kr/p/1.jpg',
    },
    {
      'category': 'kbl',
      'team': null,
      'team_id': null,
      'source': '바스켓코리아',
      'pub_date': '2026-09-09T20:00:00.000Z',
      'title': '안양 정관장 5연승',
      'description': '',
      'article_url': 'https://basketkorea.com/news/2',
      'thumbnail_url': null,
    },
    // 같은 기사가 두 번 들어와도 한 번만 남아야 한다.
    {
      'category': 'kbl',
      'source': '점프볼',
      'pub_date': '2026-09-09T12:30:00.000Z',
      'title': '서울 SK, 창원 LG 꺾고 4연승 (중복)',
      'article_url': 'https://jumpball.co.kr/news/1',
    },
    // 날짜가 깨진 기사는 조용히 버린다.
    {
      'category': 'kbl',
      'source': '루키',
      'pub_date': '어제',
      'title': '깨진 기사',
      'article_url': 'https://rookie.co.kr/news/3',
    },
  ],
};

StaticJsonNewsRepository repoReturning(
  http.Response Function(http.Request) handler,
) => StaticJsonNewsRepository(
  baseUrl: base,
  client: MockClient((request) async => handler(request)),
);

http.Response json200(Object body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('분류에 맞는 JSON 파일을 읽는다', () async {
    final requested = <String>[];
    final repository = repoReturning((request) {
      requested.add(request.url.toString());
      return json200(payload('kbl'));
    });

    await repository.getNews(category: NewsCategory.kbl);
    await repository.getNews(category: NewsCategory.overseas);
    await repository.getNews();

    expect(requested, [
      '$base/kbl.json',
      '$base/overseas.json',
      '$base/all.json', // 분류가 없으면 전체
    ]);
  });

  test('기사를 최신순으로 주고 중복·깨진 기사는 뺀다', () async {
    final repository = repoReturning((_) => json200(payload('kbl')));
    final articles = await repository.getNews();

    expect(articles, hasLength(2));
    expect(articles.first.title, '안양 정관장 5연승'); // 더 최신
    expect(articles.last.title, '서울 SK, 창원 LG 꺾고 4연승');
    expect(articles.last.thumbnailUrl, 'https://jumpball.co.kr/p/1.jpg');
    expect(articles.last.teamLabel, '서울 SK');
    expect(articles.last.url, 'https://jumpball.co.kr/news/1');
    // 빈 요약은 null로 정리된다.
    expect(articles.first.summary, isNull);
  });

  test('한글이 깨지지 않는다', () async {
    final repository = repoReturning((_) => json200(payload('kbl')));
    final articles = await repository.getNews();
    expect(articles.last.title, contains('꺾고'));
    expect(articles.last.summary, '리바운드를 장악했다.');
  });

  test('아직 수집 전(404)이면 그 사실을 알린다', () async {
    final repository = repoReturning((_) => http.Response('Not Found', 404));
    await expectLater(
      repository.getNews(),
      throwsA(
        isA<NewsUnavailableException>().having(
          (e) => e.message,
          'message',
          contains('아직 수집된 뉴스가 없어요'),
        ),
      ),
    );
  });

  test('서버 오류와 깨진 JSON은 예외로 알린다', () async {
    await expectLater(
      repoReturning((_) => http.Response('boom', 500)).getNews(),
      throwsA(isA<NewsUnavailableException>()),
    );
    await expectLater(
      repoReturning((_) => http.Response('<html>', 200)).getNews(),
      throwsA(isA<NewsUnavailableException>()),
    );
  });

  test('연결 자체가 안 되면 네트워크 안내를 준다', () async {
    final repository = StaticJsonNewsRepository(
      baseUrl: base,
      client: MockClient((_) async => throw const SocketExceptionStub()),
    );
    await expectLater(
      repository.getNews(),
      throwsA(
        isA<NewsUnavailableException>().having(
          (e) => e.message,
          'message',
          contains('네트워크'),
        ),
      ),
    );
  });

  test('articles가 없으면 빈 목록', () async {
    final repository = repoReturning((_) => json200({'category': 'all'}));
    expect(await repository.getNews(), isEmpty);
  });
}

/// 네트워크 실패를 흉내내는 예외.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
