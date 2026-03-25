import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// ESJ Zone 允许的登录后落地 host
const _kAllowedHost = 'www.esjzone.cc';
// 登录页和注册页路径，不视为登录成功
const _kExcludedPaths = ['/my/login', '/my/reg'];

class _LoginScreenState extends State<LoginScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _loginHandled = false; // 防重入锁

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            if (mounted) setState(() => _isLoading = false);
            debugPrint('WebView navigated to: $url');
            if (_isLoginSuccess(url)) {
              await _onLoginSuccess(url);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.esjzone.cc/my/login'));
  }

  /// 严格校验：必须是允许的 host，且不在排除路径列表中
  bool _isLoginSuccess(String url) {
    if (_loginHandled) return false;
    try {
      final uri = Uri.parse(url);
      if (uri.host != _kAllowedHost) return false;
      for (final path in _kExcludedPaths) {
        if (uri.path.startsWith(path)) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onLoginSuccess(String url) async {
    if (_loginHandled) return;
    _loginHandled = true; // 加锁，防止重复触发
    debugPrint('=== [ESJ] 登录成功，当前 URL: $url');
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
        automaticallyImplyLeading: false, // 禁止返回键，防止用户绕过登录
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
