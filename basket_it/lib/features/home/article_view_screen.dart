import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/news_article.dart';

/// 뉴스 카드를 누르면 열리는 원문 뷰어.
///
/// 앱을 벗어나지 않도록 웹뷰로 전체 화면에 띄우고, 브라우저로 열기·새로고침만
/// 남긴 단순한 상단바를 둔다. 웹 빌드는 웹뷰 플러그인을 쓸 수 없어
/// [openArticle]에서 새 탭으로 대신 연다.
class ArticleViewScreen extends StatefulWidget {
  final NewsArticle article;

  const ArticleViewScreen({super.key, required this.article});

  @override
  State<ArticleViewScreen> createState() => _ArticleViewScreenState();
}

class _ArticleViewScreenState extends State<ArticleViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

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
      ..loadRequest(Uri.parse(widget.article.url!));
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.article.url!);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
      body: _failed
          ? _LoadFailed(onOpenInBrowser: _openInBrowser)
          : WebViewWidget(controller: _controller),
    );
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
            const Icon(
              Icons.link_off,
              size: 44,
              color: AppColors.textTertiary,
            ),
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

/// 기사를 연다. 모바일은 앱 안 웹뷰, 웹 빌드는 새 탭.
Future<void> openArticle(BuildContext context, NewsArticle article) async {
  final url = article.url;
  if (url == null || url.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('원문 주소가 없는 기사예요.')));
    return;
  }

  if (kIsWeb) {
    // 웹 빌드에서는 webview_flutter를 쓸 수 없어 새 탭으로 연다.
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('기사를 열지 못했어요.')));
    }
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ArticleViewScreen(article: article)),
  );
}
