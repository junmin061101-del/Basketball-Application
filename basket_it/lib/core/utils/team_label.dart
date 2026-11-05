/// 긴 팀 이름의 줄임말. 팀 약칭([Team.shortName])과 좁은 표에 쓴다.
///
/// "대구 한국가스공사"는 한 줄에 다 들어가지 않아 잘리고, 잘린 이름은 어느
/// 팀인지 알기 어렵다. 팬들이 부르는 뒤쪽 이름으로 적는다.
const _aliases = {'한국가스공사': '페가수스', '현대모비스': '모비스'};

String compactTeamName(String name) {
  for (final entry in _aliases.entries) {
    if (name.contains(entry.key)) {
      return name.replaceAll(entry.key, entry.value);
    }
  }
  return name;
}
