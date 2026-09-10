import 'package:basket_it/data/models/player.dart';
import 'package:basket_it/features/explore/player_sort.dart';
import 'package:flutter_test/flutter_test.dart';

Player p(String name, String teamId, {int followers = 0, int number = 0}) =>
    Player(
      id: '$teamId-$name',
      name: name,
      teamId: teamId,
      position: PlayerPosition.pg,
      backNumber: number,
      followerCount: followers,
    );

void main() {
  final players = [
    p('하동훈', 'lg', followers: 900),
    p('김도현', 'sk', followers: 100),
    p('나성민', 'lg', followers: 500),
    p('박준영', 'sk', followers: 700),
  ];

  test('내 팀 먼저: 팔로우한 팀 선수가 앞에 오고 그 안에서 가나다순', () {
    final sorted = sortPlayers(
      players,
      sort: PlayerSort.myTeams,
      followedTeamIds: {'sk'},
    );
    expect(sorted.map((e) => e.name), ['김도현', '박준영', '나성민', '하동훈']);
  });

  test('내 팀 먼저: 팔로우한 팀이 없으면 전체 가나다순과 같다', () {
    final sorted = sortPlayers(players, sort: PlayerSort.myTeams);
    expect(sorted.map((e) => e.name), ['김도현', '나성민', '박준영', '하동훈']);
  });

  test('인기순: 팔로워 많은 순', () {
    final sorted = sortPlayers(players, sort: PlayerSort.popular);
    expect(sorted.map((e) => e.name), ['하동훈', '박준영', '나성민', '김도현']);
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
    sortPlayers(players, sort: PlayerSort.popular);
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
    expect(sortPlayers(const [], sort: PlayerSort.popular), isEmpty);
  });
}
