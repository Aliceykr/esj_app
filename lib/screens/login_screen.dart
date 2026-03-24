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
            // 跳转到 profile/forum 页说明登录成功（HttpOnly Cookie 无法用 JS 读取）
            if (url.contains('esjzone.cc') &&
                !url.contains('/my/login') &&
                !url.contains('/my/reg')) {
              await _onLoginSuccess(url);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.esjzone.cc/my/login'));
  }

  Future<void> _onLoginSuccess(String url) async {
    debugPrint('=== [ESJ] 登录成功，当前 URL: $url');
    // 登录凭证为 HttpOnly Cookie，由 WebView 自动管理，无需手动提取
    // 保存一个登录标记，让 AuthService 知道已登录
    await AuthService.markLoggedIn();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
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
