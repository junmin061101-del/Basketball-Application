import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/news_article.dart';
/// 앱 안에서 띄울 때만 쓰는 모바일 호스트 대응표.
///
/// 일부 매체는 PC 페이지에 viewport 메타가 없어 좁은 화면에서 잘려 보인다.
/// 보통은 스스로 모바일 주소로 옮겨가지만, 그 방식이 "최상위 창을 이동"이라
/// iframe sandbox가 막는다(안 막으면 앱 전체가 기사로 바뀐다). 그래서 처음부터
/// 모바일 주소로 연다.
///
/// 기사 식별과 "브라우저로 열기"에는 원래 주소를 그대로 쓴다.
const _mobileHosts = {
  'basketkorea.com': 'm.basketkorea.com',
  'www.basketkorea.com': 'm.basketkorea.com',
};

/// 앱 안에서 열 주소. 대응표에 없으면 원래 주소 그대로.
String viewerUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final mobileHost = _mobileHosts[uri.host];
  if (mobileHost == null) return url;
  return uri.replace(host: mobileHost).toString();
}

/// 뉴스 카드를 누르면 열리는 원문 뷰어(모바일 전용).
///
/// 앱을 벗어나지 않도록 원문을 전체 화면으로 띄우고, 닫기와 브라우저로 열기만
/// 남긴 단순한 상단바를 둔다. 웹에서는 이 화면을 쓰지 않고 새 탭으로 연다
/// ([openArticle] 참고).
class ArticleViewScreen extends StatefulWidget {
  final NewsArticle article;

  const ArticleViewScreen({super.key, required this.article});

  @override
  State<ArticleViewScreen> createState() => _ArticleViewScreenState();
}

class _ArticleViewScreenState extends State<ArticleViewScreen> {
  /// 웹에서는 만들지 않는다. 웹용 플랫폼 구현이 없어 생성 자체가 실패한다.
  WebViewController? _controller;
  int _progress = 0;
  bool _failed = false;

  /// 원래 기사 주소. 브라우저로 열 때 쓴다.
  String get _url => widget.article.url!;

  /// 앱 안에서 띄울 주소. 매체에 따라 모바일 호스트로 바뀔 수 있다.
  String get _inAppUrl => viewerUrl(_url);

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) => setState(() => _progress = value),
          onPageStarted: (_) => setState(() {
            _progress = 0;
            _failed = false;
          }),
          onPageFinished: (_) => setState(() => _progress = 100),
          onWebResourceError: (error) {
            // 페이지 본문 로딩이 실패했을 때만 오류 화면으로 바꾼다.
            if (error.isForMainFrame ?? true) {
              setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_inAppUrl));
  }

  Future<void> _openInBrowser() async {
    await launchUrl(
      Uri.parse(_url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.article.source,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: '브라우저로 열기',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openInBrowser,
          ),
        ],
        bottom: _progress < 100 && !_failed
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 2,
                  backgroundColor: AppColors.surface,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_failed) return _LoadFailed(onOpenInBrowser: _openInBrowser);
    return WebViewWidget(controller: _controller!);
  }
}

class _LoadFailed extends StatelessWidget {
  final VoidCallback onOpenInBrowser;

  const _LoadFailed({required this.onOpenInBrowser});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 44, color: AppColors.textTertiary),
            const SizedBox(height: 14),
            Text(
              '기사를 여는 데 실패했어요',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '언론사 사이트에서 직접 확인해보세요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onOpenInBrowser,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('브라우저로 열기'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 기사 원문을 연다. 모바일은 앱 안 웹뷰, 웹은 새 탭.
///
/// 웹에서 iframe으로 띄우던 때는 기사가 거의 열리지 않았다. 언론사가 프레임
/// 접근을 막아 "403 접근이 차단되었습니다"가 뜨거나(SPOTV뉴스 등), 기사 주소가
/// http면 브라우저가 혼합 콘텐츠로 막아 빈 화면이 됐다(루키 등). 웹에서는
/// 언론사 페이지를 새 탭에 그대로 띄우는 편이 확실하다.
Future<void> openArticle(BuildContext context, NewsArticle article) async {
  final url = article.url;
  if (url == null || url.isEmpty) {
    _tell(context, '원문 주소가 없는 기사예요.');
    return;
  }

  if (kIsWeb) {
    // 탭을 누른 흐름에서 바로 열어야 팝업 차단에 걸리지 않는다.
    final opened = await launchUrl(
      Uri.parse(url),
      webOnlyWindowName: '_blank',
    ).catchError((_) => false);
    if (!opened && context.mounted) {
      _tell(context, '기사를 열지 못했어요. 브라우저의 팝업 차단을 확인해주세요.');
    }
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ArticleViewScreen(article: article)),
  );
}

void _tell(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
