import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/novel.dart';
import '../services/auth_service.dart';
import '../services/novel_service.dart';
import '../widgets/novel_card.dart';
import '../widgets/category_bar.dart';
import 'auth_gate.dart';
import 'novel_detail_screen.dart';

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

  // O5: 过滤结果缓存，避免每次 build 重新计算
  List<Novel> _cachedFilteredNovels = [];

  late final WebViewController _webController;

  // 加载序号：每次发起新请求递增，回调时比对序号，忽略过期请求
  int _loadToken = 0;
  Completer<void>? _completer;

  @override
  void initState() {
    super.initState();
    _initWebController();
    _load();
  }

  // O7: dispose 时安全释放 Completer，防内存泄漏
  @override
  void dispose() {
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(StateError('disposed'));
    }
    _completer = null;
    super.dispose();
  }

  void _initWebController() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) {
          final completer = _completer;
          if (completer == null || completer.isCompleted) return;
          // 强制打印原始消息摘要，帮助定位选择器问题
          try {
            final raw = msg.message;
            final truncated = raw.length > 300 ? raw.substring(0, 300) : raw;
            debugPrint('[HomeScreen] FlutterBridge raw(${raw.length}b): $truncated');
          } catch (_) {}
          try {
            // O8: 传入 expectedToken，过期消息直接丢弃
            final data = NovelService.parseHomeJson(
              msg.message,
              expectedToken: _loadToken,
            );
            debugPrint('[HomeScreen] 解析到 ${data.latestNovels.length} 本小说，${data.categories.length} 个分类');
            if (mounted) {
              setState(() {
                _data = data;
                _loading = false;
                _error = null;
                _selectedCategory = null;
                // O5: 数据更新时同步更新过滤缓存
                _cachedFilteredNovels = data.latestNovels;
              });
            }
            completer.complete();
          } on StaleTokenException {
            // 过期消息，静默忽略
          } catch (e) {
            completer.completeError(e);
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          debugPrint('[HomeScreen] 页面加载完成: $url');
          if (!url.contains('esjzone.cc')) {
            debugPrint('[HomeScreen] 检测到重定向至非 esjzone.cc 域名，Session 可能已失效: $url');
            final completer = _completer;
            if (completer != null && !completer.isCompleted) {
              completer.completeError(_SessionExpiredException());
            }
            return;
          }
          // 延迟 800ms 等待 JS 框架完成渲染后再注入脚本
          await Future.delayed(const Duration(milliseconds: 800));
          final completer = _completer;
          if (completer != null && !completer.isCompleted) {
            await _webController.runJavaScript(
              NovelService.buildExtractScript(_loadToken),
            );
          }
        },
        onWebResourceError: (err) {
          debugPrint('[HomeScreen] 资源错误(isForMainFrame=${err.isForMainFrame}): ${err.description}');
          // 华为 WebView 会持续误报 isForMainFrame=true 的 SSL 错误，全部忽略
          // 只依赖 JS 脚本回调和超时机制
        },
      ));
  }

  Future<void> _load() async {
    if (!mounted) return;

    final token = ++_loadToken;

    if (_completer != null && !_completer!.isCompleted) {
      _completer!.completeError(Exception('cancelled'));
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _completer = Completer<void>();
    _webController.loadRequest(Uri.parse('${NovelService.baseUrl}/'));

    try {
      await _completer!.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw Exception('首页加载超时，请检查网络'),
      );
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      final msg = e.toString();
      if (msg.contains('cancelled') || msg.contains('disposed')) return;
      // Session 失效：清除登录态并跳回登录页
      if (e is _SessionExpiredException) {
        await AuthService.logout();
        await WebViewCookieManager().clearCookies();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthGate()),
            (_) => false,
          );
        }
        return;
      }
      setState(() {
        _error = msg;
        _loading = false;
      });
    }
  }

  // O5: 分类变更时更新过滤缓存，而非在 build 中每次重算
  void _onCategorySelected(String cat) {
    setState(() {
      _selectedCategory = _selectedCategory == cat ? null : cat;
      _cachedFilteredNovels = _applyFilter(_data?.latestNovels ?? []);
    });
  }

  List<Novel> _applyFilter(List<Novel> novels) {
    if (_selectedCategory == null) return novels;
    return novels
        .where((n) =>
            n.tags.contains(_selectedCategory) ||
            n.title.contains(_selectedCategory!))
        .toList();
  }

  Future<void> _logout() async {
    await AuthService.logout();
    await WebViewCookieManager().clearCookies();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
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
            tooltip: '退出登录',
            onPressed: _logout,
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
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (_loading)
          const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('正在加载首页...'),
                ],
              ),
            ),
          )
        else if (_error != null)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('加载失败',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            ),
          )
        else
          ..._buildContentSlivers(),
      ],
    );
  }

  List<Widget> _buildContentSlivers() {
    final data = _data!;
    // O5: 直接使用缓存的过滤结果
    final novels = _cachedFilteredNovels;

    return [
      if (data.bannerUrls.isNotEmpty)
        SliverToBoxAdapter(child: _buildBanner(data.bannerUrls)),
      if (data.categories.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CategoryBar(
              categories: data.categories,
              selected: _selectedCategory,
              onSelected: _onCategorySelected,
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.all(12),
        sliver: novels.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.menu_book_outlined,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        _selectedCategory != null
                            ? '「$_selectedCategory」分类下暂无内容'
                            : '暂无内容',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            : SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => NovelCard(
                    novel: novels[index],
                    onTap: () => _openNovel(novels[index]),
                  ),
                  childCount: novels.length,
                  // O6: 为每个 NovelCard 添加重绘边界，提升滚动 FPS
                  addRepaintBoundaries: true,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
              ),
      ),
    ];
  }

  void _openNovel(Novel novel) {
    debugPrint('[HomeScreen] 点击小说: ${novel.title} -> ${novel.url}');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NovelDetailScreen(novel: novel),
      ),
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
                errorBuilder: (context, err, stack) =>
                    Container(color: Colors.grey[200]),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// WebView 检测到被重定向出 esjzone.cc，说明 Session 已失效
class _SessionExpiredException implements Exception {
  const _SessionExpiredException();
}
