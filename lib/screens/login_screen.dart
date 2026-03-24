import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (url) async {
            setState(() => _isLoading = false);
            debugPrint('WebView navigated to: $url');
            // 只要离开了登录页就尝试提取 Cookie
            if (!url.contains('/my/login') && url.contains('esjzone.cc')) {
              await _extractAndSaveCookies();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.esjzone.cc/my/login'));
  }

  Future<void> _extractAndSaveCookies() async {
    // 用 JS 读取所有非 HttpOnly Cookie
    final jsResult = await _controller.runJavaScriptReturningResult('document.cookie');
    final jsCookie = jsResult.toString().replaceAll('"', '');
    debugPrint('JS Cookie: $jsCookie');

    // 用 JS 读取 localStorage 中可能存的 token
    final lsResult = await _controller.runJavaScriptReturningResult(
      'JSON.stringify({ews_token: localStorage.getItem("ews_token"), ews_key: localStorage.getItem("ews_key")})',
    );
    debugPrint('LocalStorage: $lsResult');

    // 检查是否包含登录凭证
    if (jsCookie.contains('ews_token') || jsCookie.contains('ews_key') || jsCookie.isNotEmpty) {
      await AuthService.saveCookie(jsCookie);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } else {
      debugPrint('Cookie empty, not navigating yet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录 ESJ Zone'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
