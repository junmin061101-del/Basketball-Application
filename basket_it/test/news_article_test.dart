import 'package:basket_it/data/models/news_article.dart';
import 'package:basket_it/data/repositories/news_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<Object?, Object?> sample({
    Object? category = 'kbl',
    Object? articleUrl = 'https://jumpball.co.kr/news/1',
    Object? pubDate = '2026-09-08T01:00:00.000Z',
    Object? title = '서울 SK, 창원 LG 꺾고 4연승',
  }) => {
    'category': category,
    'team': '서울 SK',
    'team_id': 'sk',
    'source': '점프볼',
    'pub_date': pubDate,
    'title': title,
    'description': '리바운드를 장악하며 승리했다.',
    'article_url': articleUrl,
    'thumbnail_url': 'https://jumpball.co.kr/img/1.jpg',
  };

  test('서버 응답을 기사 모델로 바꾼다', () {
    final article = NewsArticle.tryParse(sample())!;

    expect(article.id, 'https://jumpball.co.kr/news/1');
    expect(article.url, 'https://jumpball.co.kr/news/1');
    expect(article.category, NewsCategory.kbl);
    expect(article.teamLabel, '서울 SK');
    expect(article.relatedTeamId, 'sk');
    expect(article.source, '점프볼');
    expect(article.thumbnailUrl, 'https://jumpball.co.kr/img/1.jpg');
    expect(article.publishedAt.toUtc(), DateTime.utc(2026, 9, 8, 1));
  });

  test('NBA 기사는 nba로 읽고, KBL·NBA가 아닌 기사(예전 해외파 등)는 받지 않는다', () {
    expect(NewsArticle.tryParse(sample(category: 'nba'))!.category, NewsCategory.nba);
    expect(NewsArticle.tryParse(sample(category: 'overseas')), isNull);
  });

  test('필수 필드가 빠지거나 날짜가 깨지면 null', () {
    expect(NewsArticle.tryParse(sample(articleUrl: null)), isNull);
    expect(NewsArticle.tryParse(sample(title: null)), isNull);
    expect(NewsArticle.tryParse(sample(pubDate: '어제')), isNull);
  });

  test('빈 요약은 null로 둔다', () {
    final json = sample()..['description'] = '';
    expect(NewsArticle.tryParse(json)!.summary, isNull);
  });

  test('같은 원문 URL이면 같은 기사로 본다', () {
    final a = NewsArticle.tryParse(sample())!;
    final b = NewsArticle.tryParse(sample(title: '제목만 다름'))!;
    expect({a, b}.length, 1);
  });

  test('분류의 서버 전달값', () {
    expect(NewsCategory.kbl.wireName, 'kbl');
    expect(NewsCategory.nba.wireName, 'nba');
  });

  test('정렬의 네이버 전달값', () {
    expect(NewsSort.date.wireName, 'date');
    expect(NewsSort.similarity.wireName, 'sim');
  });
}
