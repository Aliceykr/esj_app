import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_service.dart';
import '../services/novel_service.dart';
import '../widgets/novel_card.dart';
import '../widgets/category_bar.dart';
import 'auth_gate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeData? _data;
  bool _loading = true;
  String? _error;
  String? _selectedCategory;

  late final WebViewController _webController;
  Completer<void>? _completer;

  @override
  void initState() {
    super.initState();
    _initWebController();
    _load();
  }

  void _initWebController() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) {
          if (_completer == null || _completer!.isCompleted) return;
          try {
            final data = NovelService.parseHomeJson(msg.message);
            debugPrint('[HomeScreen] 解析到 ${data.latestNovels.length} 本小说');
            if (mounted) {
              setState(() {
                _data = data;
                _loading = false;
                _error = null;
              });
            }
            _completer!.complete();
          } catch (e) {
            _completer!.completeError(e);
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          if (!url.contains('esjzone.cc')) return;
          debugPrint('[HomeScreen] 页面加载完成: $url');
          // 等待动态内容渲染
          await Future.delayed(const Duration(seconds: 2));
          if (_completer != null && !_completer!.isCompleted) {
            await _webController.runJavaScript(NovelService.extractScript);
          }
        },
        onWebResourceError: (err) {
          debugPrint('[HomeScreen] 资源错误(isForMainFrame=${err.isForMainFrame}): ${err.description}');
          // 只处理主框架错误，忽略广告/第三方子资源的网络错误
          if (err.isForMainFrame == true &&
              _completer != null &&
              !_completer!.isCompleted) {
            _completer!.completeError(Exception(err.description));
          }
        },
      ));
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    _completer = Completer<void>();
    _webController.loadRequest(Uri.parse('${NovelService.baseUrl}/'));

    try {
      await _completer!.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw Exception('首页加载超时，请检查网络'),
      );
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESJ Zone'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('正在加载首页...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    final data = _data!;
    return CustomScrollView(
      slivers: [
        if (data.bannerUrls.isNotEmpty)
          SliverToBoxAdapter(child: _buildBanner(data.bannerUrls)),
        if (data.categories.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CategoryBar(
                categories: data.categories,
                selected: _selectedCategory,
                onSelected: (cat) => setState(() => _selectedCategory = cat),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: data.latestNovels.isEmpty
              ? const SliverToBoxAdapter(
                  child: Center(child: Text('暂无内容')),
                )
              : SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => NovelCard(novel: data.latestNovels[index]),
                    childCount: data.latestNovels.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBanner(List<String> urls) {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                urls[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(color: Colors.grey[200]),
              ),
            ),
          );
        },
      ),
    );
  }
}
