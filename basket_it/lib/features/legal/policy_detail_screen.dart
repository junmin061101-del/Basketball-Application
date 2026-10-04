import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import 'policy_documents.dart';

/// 이용약관·개인정보처리방침을 보여주는 화면.
///
/// 본문은 앱에 담긴 마크다운 파일을 그대로 읽어 그린다. 문서가 원본이고 화면은
/// 그것을 보여주기만 하므로, 약관을 고칠 때 Dart 코드를 건드릴 일이 없다.
class PolicyDetailScreen extends StatelessWidget {
  final PolicyDocument document;

  const PolicyDetailScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(document.assetPath),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '문서를 불러오지 못했어요.\n문의: $contactEmail',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          final markdown = snapshot.data;
          if (markdown == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: markdownBlocks(markdown),
            ),
          );
        },
      ),
    );
  }
}

/// 마크다운 한 편을 위젯 목록으로 바꾼다.
///
/// 약관 문서에 쓰는 만큼만 읽는다: 제목(#, ##, ###), 글머리표(-), 번호 목록(1.),
/// 굵은 글씨(**), 링크([글](주소)), 그리고 보통 문단. 표는 쓰지 않는다.
/// 목록 안에서 줄을 바꿔 쓴 글(들여쓴 다음 줄)은 그 항목에 이어 붙인다.
List<Widget> markdownBlocks(String markdown) {
  final blocks = <Widget>[];
  final paragraph = <String>[];
  String? itemMarker;
  final itemText = <String>[];
  var itemIndent = 0.0;

  void flushItem() {
    if (itemMarker == null) return;
    blocks.add(_bullet(itemMarker!, itemText.join(' '), itemIndent));
    itemMarker = null;
    itemText.clear();
  }

  void flushParagraph() {
    flushItem();
    if (paragraph.isEmpty) return;
    blocks.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _InlineText(paragraph.join(' '), style: _bodyStyle),
      ),
    );
    paragraph.clear();
  }

  void startItem(String marker, String text, double indent) {
    flushParagraph();
    itemMarker = marker;
    itemText.add(text);
    itemIndent = indent;
  }

  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trimLeft();
    final spaces = line.length - trimmed.length;
    // 들여쓴 목록은 한 칸 더 들여 그린다.
    final indent = spaces >= 2 ? 16.0 : 0.0;

    if (trimmed.isEmpty) {
      flushParagraph();
      continue;
    }
    if (trimmed.startsWith('### ')) {
      flushParagraph();
      blocks.add(_heading(trimmed.substring(4), 15, 20));
      continue;
    }
    if (trimmed.startsWith('## ')) {
      flushParagraph();
      blocks.add(_heading(trimmed.substring(3), 17.5, 26));
      continue;
    }
    if (trimmed.startsWith('# ')) {
      flushParagraph();
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            trimmed.substring(2),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
      continue;
    }
    if (trimmed.startsWith('- ')) {
      startItem('·', trimmed.substring(2), indent);
      continue;
    }
    final numbered = RegExp(r'^(\d+)\. (.*)$').firstMatch(trimmed);
    if (numbered != null) {
      startItem('${numbered.group(1)}.', numbered.group(2)!, indent);
      continue;
    }
    // 들여쓴 줄은 바로 앞 목록 항목이 이어지는 것이다.
    if (spaces >= 2 && itemMarker != null) {
      itemText.add(trimmed);
      continue;
    }
    flushItem();
    paragraph.add(trimmed);
  }
  flushParagraph();
  return blocks;
}

const _bodyStyle = TextStyle(
  fontSize: 14,
  height: 1.65,
  color: AppColors.textSecondary,
);

Widget _heading(String text, double size, double top) => Padding(
  padding: EdgeInsets.only(top: top, bottom: 10),
  child: Text(
    text,
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    ),
  ),
);

Widget _bullet(String marker, String text, double indent) => Padding(
  padding: EdgeInsets.only(left: indent, bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 22,
        child: Text(
          marker,
          style: _bodyStyle.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      Expanded(child: _InlineText(text, style: _bodyStyle)),
    ],
  ),
);

/// `**굵게**`와 `[글](주소)`만 처리하는 한 줄.
class _InlineText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _InlineText(this.text, {required this.style});

  @override
  State<_InlineText> createState() => _InlineTextState();
}

class _InlineTextState extends State<_InlineText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)]+)\)');
    var index = 0;
    for (final match in pattern.allMatches(widget.text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: widget.text.substring(index, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        );
      } else {
        final url = match.group(3)!;
        final recognizer = TapGestureRecognizer()
          ..onTap = () => launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(
              color: AppColors.accent,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent,
            ),
            recognizer: recognizer,
          ),
        );
      }
      index = match.end;
    }
    if (index < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(index)));
    }

    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
