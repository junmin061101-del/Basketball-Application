import 'package:basket_it/core/utils/player_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('한글 이름은 끝 글자를 쓴다', () {
    expect(playerInitial('서준영'), '영');
    expect(playerInitial('권민준'), '준');
    expect(playerInitial('이'), '이');
  });

  test('영문 이름은 성과 이름의 첫 글자를 딴다', () {
    // 끝 글자를 쓰면 "A.J. Lawson"이 "n"이 돼 아바타가 뜻을 잃는다.
    expect(playerInitial('A.J. Lawson'), 'AL');
    expect(playerInitial('LeBron James'), 'LJ');
    expect(playerInitial('Giannis Antetokounmpo'), 'GA');
  });

  test('영문 한 단어는 첫 글자만', () {
    expect(playerInitial('Nikola'), 'N');
  });

  test('세 단어 이상이어도 두 글자까지만', () {
    expect(playerInitial('Karl Anthony Towns'), 'KA');
  });

  test('빈 값과 공백은 물음표', () {
    expect(playerInitial(''), '?');
    expect(playerInitial('   '), '?');
  });

  test('앞뒤 공백은 무시한다', () {
    expect(playerInitial('  LeBron James  '), 'LJ');
  });
}
