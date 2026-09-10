import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// 웹 빌드에서 기사 원문을 앱 화면 안에 띄운다.
///
/// webview_flutter는 웹을 지원하지 않으므로 iframe을 직접 붙인다.
/// 뉴스 매체들이 X-Frame-Options나 frame-ancestors를 걸어두지 않아
/// 이 방식이 통한다.
///
/// sandbox에서 allow-top-navigation을 빼는 게 중요하다. 일부 사이트가
/// "프레임 안이면 최상위로 이동" 스크립트를 갖고 있는데, 그게 동작하면
/// 앱 전체가 기사 페이지로 바뀌어 버린다.
const _sandbox = 'allow-scripts allow-same-origin allow-popups allow-forms';

/// 같은 viewType을 두 번 등록하면 실패하므로 이미 등록한 것을 기억한다.
final _registered = <String>{};

Widget buildArticleFrame(String url) {
  final viewType = 'article-frame:$url';

  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final frame = web.HTMLIFrameElement()
        ..src = url
        ..allow = 'fullscreen'
        ..setAttribute('sandbox', _sandbox)
        ..setAttribute('referrerpolicy', 'no-referrer-when-downgrade');
      frame.style
        ..border = 'none'
        ..width = '100%'
        ..height = '100%';
      return frame;
    });
  }

  return HtmlElementView(viewType: viewType);
}
