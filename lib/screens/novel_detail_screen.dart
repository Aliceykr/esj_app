import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/novel.dart';

class NovelDetailScreen extends StatefulWidget {
  final Novel novel;

  const NovelDetailScreen({super.key, required this.novel});

  @override
  State<NovelDetailScreen> createState() => _NovelDetailScreenState();
}

class _NovelDetailScreenState extends State<NovelDetailScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (_) async {
          if (mounted) setState(() => _isLoading = false);
          final canGoBack = await _controller.canGoBack();
          if (mounted) setState(() => _canGoBack = canGoBack);
          // 注入阅读优化 CSS：隐藏广告，优化正文字体
          await _controller.runJavaScript(_readingCss);
        },
        onWebResourceError: (err) {
          if (err.isForMainFrame == true && mounted) {
            setState(() => _isLoading = false);
          }
        },
      ))
      ..loadRequest(
        Uri.parse(widget.novel.url),
        headers: {'Referer': 'https://www.esjzone.cc/'},
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.novel.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: () => _controller.reload(),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              tooltip: '复制当前链接',
              onPressed: _copyCurrentUrl,
            ),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.transparent,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyCurrentUrl() async {
    final url = await _controller.currentUrl();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(url ?? widget.novel.url),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// 注入阅读优化样式：隐藏广告横幅，优化正文可读性
const _readingCss = r"""
(function() {
  var style = document.getElementById('esj-reading-style');
  if (style) return;
  style = document.createElement('style');
  style.id = 'esj-reading-style';
  style.textContent = [
    '.google-auto-placed, .adsbygoogle, [id*="ad"], [class*="ad-"] { display:none!important; }',
    '.forum-content p { font-size: 16px!important; line-height: 1.8!important; }'
  ].join('');
  document.head.appendChild(style);
})();
""";
