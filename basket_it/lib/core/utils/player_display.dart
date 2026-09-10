import 'package:flutter/widgets.dart';

/// 선수 이름에서 아바타에 넣을 글자를 고른다.
///
/// 한글 이름은 끝 글자(이름의 마지막 글자)를 쓰는 게 자연스럽고,
/// 영문 이름은 그렇게 하면 "A.J. Lawson"이 "n"이 돼 버린다.
/// 영문은 성과 이름의 첫 글자를 딴다.
String playerInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';

  final hasHangul = RegExp(r'[가-힣]').hasMatch(trimmed);
  if (hasHangul) return trimmed.characters.last;

  // "A.J. Lawson" → "AL", "LeBron James" → "LJ", "Nikola" → "N"
  final words = trimmed
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final letters = words
      .map((w) => RegExp(r'[A-Za-z]').firstMatch(w)?.group(0))
      .whereType<String>()
      .toList();
  if (letters.isEmpty) return trimmed.characters.first;
  return letters.take(2).join().toUpperCase();
}
