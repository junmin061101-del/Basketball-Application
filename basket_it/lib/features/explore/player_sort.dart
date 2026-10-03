import '../../data/models/league.dart';
import '../../data/models/player.dart';

/// 선수 목록 정렬 방식.
enum PlayerSort {
  /// 내가 팔로우한 팀의 선수를 먼저, 그 안에서 가나다순.
  /// 팔로우한 팀이 없으면 그냥 전체 가나다순이 된다.
  myTeams,

  /// 이름 가나다순.
  name,

  /// 영문 이름 알파벳순. 영문 이름이 없는 선수는 뒤로 보낸다.
  alphabet,

  /// 팀을 하나 골라서 그 팀 선수만. 고르기 전에는 팀 이름 가나다순으로 묶어 보여준다.
  byTeam;

  String get label => switch (this) {
    PlayerSort.myTeams => '나의 팀',
    PlayerSort.name => '가나다순',
    PlayerSort.alphabet => 'ABC순',
    PlayerSort.byTeam => '팀별',
  };
}

/// [league]에서 고를 수 있는 정렬.
///
/// 이름이 한글뿐인 KBL에 ABC순은 쓸 데가 없고, 이름을 영문으로 보여주는
/// NBA에 가나다순은 맞지 않는다. 리그마다 쓰는 것만 남긴다.
List<PlayerSort> sortsFor(League league) => switch (league) {
  League.kbl => const [PlayerSort.myTeams, PlayerSort.name, PlayerSort.byTeam],
  League.nba => const [
    PlayerSort.myTeams,
    PlayerSort.alphabet,
    PlayerSort.byTeam,
  ],
};

/// 한글 이름 비교.
///
/// 한글 음절(가~힣)은 유니코드에서 초성·중성·종성 순으로 배열돼 있어
/// 코드 단위 비교가 곧 가나다순이 된다. 이름이 같으면 등번호로 갈라
/// 순서가 흔들리지 않게 한다.
int _byName(Player a, Player b) {
  final byName = a.name.compareTo(b.name);
  if (byName != 0) return byName;
  return a.backNumber.compareTo(b.backNumber);
}

/// 영문 이름 비교. 영문 이름이 없는 선수는 뒤로 보내고 한글 이름끼리 정렬한다.
int _byEnglishName(Player a, Player b) {
  final aEn = a.englishName?.trim();
  final bEn = b.englishName?.trim();
  final aHas = aEn != null && aEn.isNotEmpty;
  final bHas = bEn != null && bEn.isNotEmpty;
  if (aHas != bHas) return aHas ? -1 : 1;
  if (!aHas) return _byName(a, b);
  final byEnglish = aEn.toLowerCase().compareTo(bEn!.toLowerCase());
  if (byEnglish != 0) return byEnglish;
  return _byName(a, b);
}

/// [players]를 [sort] 기준으로 정렬한 새 목록을 준다. 원본은 건드리지 않는다.
///
/// [followedTeamIds]는 [PlayerSort.myTeams]에서만 쓰이고,
/// [teamNameOf]는 [PlayerSort.byTeam]에서 팀 이름을 가나다순으로 놓는 데 쓴다.
List<Player> sortPlayers(
  List<Player> players, {
  required PlayerSort sort,
  Set<String> followedTeamIds = const {},
  String Function(String teamId)? teamNameOf,
}) {
  final sorted = [...players];

  switch (sort) {
    case PlayerSort.myTeams:
      sorted.sort((a, b) {
        final aMine = followedTeamIds.contains(a.teamId);
        final bMine = followedTeamIds.contains(b.teamId);
        if (aMine != bMine) return aMine ? -1 : 1;
        return _byName(a, b);
      });

    case PlayerSort.name:
      sorted.sort(_byName);

    case PlayerSort.alphabet:
      sorted.sort(_byEnglishName);

    case PlayerSort.byTeam:
      final nameOf = teamNameOf ?? (id) => id;
      sorted.sort((a, b) {
        final byTeam = nameOf(a.teamId).compareTo(nameOf(b.teamId));
        if (byTeam != 0) return byTeam;
        return _byName(a, b);
      });
  }

  return sorted;
}
