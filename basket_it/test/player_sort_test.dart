import 'package:basket_it/data/models/player.dart';
import 'package:basket_it/features/explore/player_sort.dart';
import 'package:flutter_test/flutter_test.dart';

Player p(
  String name,
  String teamId, {
  int followers = 0,
  int number = 0,
  String? englishName,
}) => Player(
  id: '$teamId-$name',
  name: name,
  teamId: teamId,
  position: PlayerPosition.pg,
  backNumber: number,
  followerCount: followers,
  englishName: englishName,
);

void main() {
  final players = [
    p('하동훈', 'lg', followers: 900),
    p('김도현', 'sk', followers: 100),
    p('나성민', 'lg', followers: 500),
    p('박준영', 'sk', followers: 700),
  ];

  test('나의 팀: 팔로우한 팀 선수가 앞에 오고 그 안에서 가나다순', () {
    final sorted = sortPlayers(
      players,
      sort: PlayerSort.myTeams,
      followedTeamIds: {'sk'},
    );
    expect(sorted.map((e) => e.name), ['김도현', '박준영', '나성민', '하동훈']);
  });

  test('나의 팀: 팔로우한 팀이 없으면 전체 가나다순과 같다', () {
    final sorted = sortPlayers(players, sort: PlayerSort.myTeams);
    expect(sorted.map((e) => e.name), ['김도현', '나성민', '박준영', '하동훈']);
  });

  test('ABC순: 영문 이름 알파벳순, 영문 이름이 없으면 뒤로', () {
    final withEnglish = [
      p('하동훈', 'lg', englishName: 'Ha Dong Hun'),
      p('김도현', 'sk', englishName: 'Kim Do Hyun'),
      p('나성민', 'lg'), // 영문 이름 없음
      p('박준영', 'sk', englishName: 'Bak Jun Young'),
    ];
    final sorted = sortPlayers(withEnglish, sort: PlayerSort.alphabet);
    expect(sorted.map((e) => e.name), ['박준영', '하동훈', '김도현', '나성민']);
  });

  test('정렬 이름표', () {
    expect(PlayerSort.values.map((s) => s.label), [
      '나의 팀',
      '가나다순',
      'ABC순',
      '팀별',
    ]);
  });

  test('가나다순', () {
    final sorted = sortPlayers(players, sort: PlayerSort.name);
    expect(sorted.map((e) => e.name), ['김도현', '나성민', '박준영', '하동훈']);
  });

  test('팀별: 팀 이름 가나다순으로 묶고 팀 안에서는 가나다순', () {
    final sorted = sortPlayers(
      players,
      sort: PlayerSort.byTeam,
      teamNameOf: (id) => switch (id) {
        'sk' => '서울 SK',
        'lg' => '창원 LG',
        _ => id,
      },
    );
    // 서울 SK가 창원 LG보다 가나다순으로 앞
    expect(sorted.map((e) => e.name), ['김도현', '박준영', '나성민', '하동훈']);
  });

  test('원본 목록을 바꾸지 않는다', () {
    final original = [...players];
    sortPlayers(players, sort: PlayerSort.name);
    expect(players.map((e) => e.name), original.map((e) => e.name));
  });

  test('이름이 같으면 등번호로 갈라 순서가 흔들리지 않는다', () {
    final same = [
      p('김민수', 'sk', number: 23),
      p('김민수', 'lg', number: 7),
    ];
    final sorted = sortPlayers(same, sort: PlayerSort.name);
    expect(sorted.map((e) => e.backNumber), [7, 23]);
  });

  test('빈 목록도 처리한다', () {
    expect(sortPlayers(const [], sort: PlayerSort.alphabet), isEmpty);
  });
}
