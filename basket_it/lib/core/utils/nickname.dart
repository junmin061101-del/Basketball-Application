/// 닉네임 규칙.
///
/// 커뮤니티 글·예측 토론·랭킹에 그대로 보이는 이름이라, 남을 사칭하거나
/// 자리만 차지하는 이름이 들어오지 않도록 여기서 한 번에 막는다.
const nicknameMinLength = 2;
const nicknameMaxLength = 10;

/// 쓸 수 없는 이름. 앱이 스스로 붙이는 이름과 겹치면 안 된다.
const _reservedPrefixes = ['게스트', '관리자', 'admin', 'Baskit'];
const _reservedNames = ['탈퇴한 사용자', '익명', '사용자'];

/// 한글·영문·숫자·밑줄만. 띄어쓰기와 특수문자는 받지 않는다.
final _allowed = RegExp(r'^[가-힣a-zA-Z0-9_]+$');

/// 닉네임이 쓸 수 있는지 본다. 쓸 수 있으면 null, 아니면 이유를 돌려준다.
String? nicknameError(String value) {
  final name = value.trim();
  if (name.isEmpty) return '닉네임을 입력해 주세요';
  final length = name.runes.length;
  if (length < nicknameMinLength) {
    return '$nicknameMinLength자 이상 입력해 주세요';
  }
  if (length > nicknameMaxLength) {
    return '$nicknameMaxLength자까지 쓸 수 있어요';
  }
  if (!_allowed.hasMatch(name)) {
    return '한글·영문·숫자·밑줄만 쓸 수 있어요';
  }
  final lower = name.toLowerCase();
  if (_reservedNames.any((n) => n.toLowerCase() == lower)) {
    return '쓸 수 없는 닉네임이에요';
  }
  if (_reservedPrefixes.any((p) => lower.startsWith(p.toLowerCase()))) {
    return '쓸 수 없는 닉네임이에요';
  }
  return null;
}

bool isValidNickname(String value) => nicknameError(value) == null;

/// 저장할 모양으로 다듬는다(앞뒤 공백만 떼어 낸다).
String normalizeNickname(String value) => value.trim();
