import 'package:flutter/widgets.dart';

/// 웹이 아닌 플랫폼에서는 쓰이지 않는다.
/// (모바일은 webview_flutter로 원문을 띄운다)
Widget buildArticleFrame(String url) => const SizedBox.shrink();
