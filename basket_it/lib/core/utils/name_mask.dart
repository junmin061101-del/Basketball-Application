/// 일반 사용자 이름을 화면에 보여줄 때 쓰는 마스킹.
///
/// 승부예측 랭킹·토론에 참여하는 사람은 공인이 아니라 일반인이므로,
/// 이름을 그대로 노출하지 않고 가운데를 별표로 가린다.
/// 예) 강민수 → 강*수, 김도윤 → 김*윤, 이하 → 이*, 최윤아무개 → 최***개
String maskDisplayName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '익명';

  // 게스트-xxxx 처럼 이미 익명 식별자면 그대로 둔다.
  if (trimmed.startsWith('게스트')) return trimmed;

  // 이메일이면 아이디 부분만 남겨서 마스킹한다.
  final base = trimmed.contains('@') ? trimmed.split('@').first : trimmed;
  final chars = base.runes.toList();

  if (chars.length == 1) return base;
  if (chars.length == 2) return '${String.fromCharCode(chars.first)}*';

  final first = String.fromCharCode(chars.first);
  final last = String.fromCharCode(chars.last);
  return '$first${'*' * (chars.length - 2)}$last';
}
