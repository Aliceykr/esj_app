import 'dart:async';
import 'dart:convert';
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
  List<Novel> _cachedFilteredNovels = [];

  late final WebViewController _webController;

  // 防竞态：每次新请求递增，回调时比对忽略过期
  int _loadToken = 0;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _initWebController();
    _load();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _initWebController() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) async {
          debugPrint('[HomeScreen] 页面加载完成: $url');
          if (!url.contains('esjzone.cc')) {
            debugPrint('[HomeScreen] 重定向至非 esjzone.cc，Session 可能已失效: $url');
            await _handleSessionExpired();
            return;
          }
          final token = _loadToken;
          // 等待 DOM 稳定（服务端渲染不需要等 JS 框架，500ms 足够）
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted || token != _loadToken) return;
          try {
            final raw = await _webController.runJavaScriptReturningResult(
              'document.documentElement.outerHTML',
            );
            // Android WebView 返回带 JSON 转义的字符串，需要 jsonDecode 还原
            final html = raw is String
                ? (raw.startsWith('"') ? jsonDecode(raw) as String : raw)
                : raw.toString();
            // 检测空壳页（html.length < 100）或华为错误页
            if (html.length < 100 || html.contains('ERR_CONNECTION_TIMED_OUT') || html.contains('网页无法打开')) {
              throw Exception('网络连接失败，无法访问 esjzone.cc\n请检查网络或使用代理后重试');
            }
            final data = NovelService.parseHomeHtml(html);
            _timeoutTimer?.cancel();
            if (mounted && token == _loadToken) {
              setState(() {
                _data = data;
                _loading = false;
                _error = null;
                _selectedCategory = null;
                _cachedFilteredNovels = data.latestNovels;
              });
            }
          } catch (e) {
            debugPrint('[HomeScreen] 解析失败: $e');
            _timeoutTimer?.cancel();
            if (mounted && token == _loadToken) {
              setState(() {
                _error = '解析失败: $e';
                _loading = false;
              });
            }
          }
        },
        onWebResourceError: (err) {
          debugPrint('[HomeScreen] 资源错误(isForMainFrame=${err.isForMainFrame}): ${err.description}');
          // 华为 WebView 误报，不处理；依赖 onPageFinished 驱动
        },
      ));
  }

  Future<void> _load() async {
    if (!mounted) return;
    _timeoutTimer?.cancel();
    final token = ++_loadToken;

    setState(() {
      _loading = true;
      _error = null;
    });

    _webController.loadRequest(Uri.parse('${NovelService.baseUrl}/'));

    // 30s 超时兜底：onPageFinished 未触发时提示用户
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && token == _loadToken && _loading) {
        setState(() {
          _error = '首页加载超时，请检查网络后重试';
          _loading = false;
        });
      }
    });
  }

  Future<void> _handleSessionExpired() async {
    _timeoutTimer?.cancel();
    await AuthService.logout();
    await WebViewCookieManager().clearCookies();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }
  }

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
