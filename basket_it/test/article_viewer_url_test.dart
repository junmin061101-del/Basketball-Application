import 'package:basket_it/features/home/article_view_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('모바일 페이지가 따로 있는 매체는 그 주소로 연다', () {
    // 이 매체는 PC 페이지에 viewport 메타가 없어 좁은 화면에서 잘린다.
    expect(
      viewerUrl('https://basketkorea.com/news/newsview.php?ncode=106557'),
      'https://m.basketkorea.com/news/newsview.php?ncode=106557',
    );
    expect(
      viewerUrl('https://www.basketkorea.com/news/newsview.php?ncode=1'),
      'https://m.basketkorea.com/news/newsview.php?ncode=1',
    );
  });

  test('대응표에 없는 매체는 주소를 그대로 쓴다', () {
    const url = 'https://sports.donga.com/sports/article/all/20260910/1.html';
    expect(viewerUrl(url), url);
    expect(viewerUrl('https://www.rookie.co.kr/news/articleView.html?idxno=1'),
        'https://www.rookie.co.kr/news/articleView.html?idxno=1');
  });

  test('경로와 쿼리는 건드리지 않는다', () {
    expect(
      viewerUrl('https://basketkorea.com/a/b?x=1&y=2#top'),
      'https://m.basketkorea.com/a/b?x=1&y=2#top',
    );
  });

  test('주소가 아니면 그대로 돌려준다', () {
    expect(viewerUrl('::not a url::'), '::not a url::');
  });
}
