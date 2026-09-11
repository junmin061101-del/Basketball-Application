import 'package:flutter/foundation.dart';

/// 팀 순위표 한 줄(승/패 기록).
@immutable
class TeamStanding {
  final String teamId;
  final int wins;
  final int losses;

  /// 1위 팀과의 게임차. NBA는 같은 컨퍼런스 1위와의 게임차다.
  final double gamesBehind;

  /// 컨퍼런스("east" / "west"). KBL처럼 컨퍼런스가 없는 리그는 빈 문자열.
  final String conference;

  /// 컨퍼런스 안 시드(동률 타이브레이커 반영). 원본이 주지 않으면 null.
  final int? seed;

  const TeamStanding({
    required this.teamId,
    required this.wins,
    required this.losses,
    required this.gamesBehind,
    this.conference = '',
    this.seed,
  });

  int get gamesPlayed => wins + losses;
  double get winPct => gamesPlayed == 0 ? 0 : wins / gamesPlayed;
}

/// 순위표 한 묶음. NBA는 동부·서부 두 개, KBL은 하나다.
@immutable
class StandingsGroup {
  /// 화면에 쓰는 제목("동부 컨퍼런스"). 컨퍼런스가 없는 리그는 null.
  final String? title;

  /// 순위순으로 정렬된 팀들.
  final List<TeamStanding> rows;

  const StandingsGroup(this.title, this.rows);
}

/// "east" / "Eastern Conference" → "east". 예전 수집 결과는 긴 이름으로 온다.
String _conferenceKey(String value) {
  final lower = value.toLowerCase();
  if (lower.contains('east')) return 'east';
  if (lower.contains('west')) return 'west';
  return '';
}

const _conferenceTitles = {'east': '동부 컨퍼런스', 'west': '서부 컨퍼런스'};

/// 순위표를 컨퍼런스별로 나누고 각 묶음을 순위순으로 정렬한다.
///
/// NBA 순위는 컨퍼런스 안에서 매긴다. 30팀을 승률 하나로 섞으면 동부 3위와
/// 서부 3위가 뒤엉켜 실제 순위와 다르게 보인다. 묶음 안에서는 시드(동률
/// 타이브레이커 반영)를 따르고, 시드가 없으면 원본 순서를 그대로 둔다. KBL은
/// 원본이 공식 순위순으로 준다.
List<StandingsGroup> groupStandings(List<TeamStanding> standings) {
  final byKey = <String, List<TeamStanding>>{};
  for (final s in standings) {
    byKey.putIfAbsent(_conferenceKey(s.conference), () => []).add(s);
  }
  const order = ['east', 'west', ''];
  final keys = byKey.keys.toList()
    ..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));

  return [
    for (final key in keys)
      StandingsGroup(
        _conferenceTitles[key],
        [...byKey[key]!]..sort(
          (a, b) =>
              a.seed != null && b.seed != null ? a.seed!.compareTo(b.seed!) : 0,
        ),
      ),
  ];
}

/// [teamId]의 순위 표기. 컨퍼런스가 있으면 "동부 3위", 없으면 "리그 3위".
/// 순위표에 없는 팀이면 null.
String? rankLabelOf(List<TeamStanding> standings, String teamId) {
  for (final group in groupStandings(standings)) {
    final index = group.rows.indexWhere((s) => s.teamId == teamId);
    if (index < 0) continue;
    final scope = group.title?.split(' ').first ?? '리그';
    return '$scope ${index + 1}위';
  }
  return null;
}
