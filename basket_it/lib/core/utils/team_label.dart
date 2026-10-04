/// 표처럼 좁은 자리에 쓰는 팀 이름.
///
/// "대구 한국가스공사"는 한 줄에 다 들어가지 않아 잘리고, 잘린 이름은 어느
/// 팀인지 알기 어렵다. 중계·기사에서 흔히 쓰는 줄임말로 적는다.
const _aliases = {'한국가스공사': '가스공사', '현대모비스': '모비스'};

String compactTeamName(String name) {
  for (final entry in _aliases.entries) {
    if (name.contains(entry.key)) {
      return name.replaceAll(entry.key, entry.value);
    }
  }
  return name;
}
