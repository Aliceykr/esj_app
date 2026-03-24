import 'dart:convert';
import '../models/novel.dart';

class HomeData {
  final List<String> bannerUrls;
  final List<String> categories;
  final List<Novel> latestNovels;

  const HomeData({
    required this.bannerUrls,
    required this.categories,
    required this.latestNovels,
  });
}

class NovelService {
  static const baseUrl = 'https://www.esjzone.cc';

  /// 解析从 WebView JS 桥接回传的 JSON 数据
  static HomeData parseHomeJson(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;

    final banners = (map['banners'] as List? ?? [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();

    final categories = (map['categories'] as List? ?? [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .take(12)
        .toList();

    final novels = (map['novels'] as List? ?? []).map((e) {
      final m = e as Map<String, dynamic>;
      final cover = m['cover']?.toString() ?? '';
      final url = m['url']?.toString() ?? '';
      return Novel(
        title: m['title']?.toString() ?? '',
        coverUrl: cover.startsWith('http') ? cover : '$baseUrl$cover',
        author: m['author']?.toString() ?? '',
        url: url.startsWith('http') ? url : '$baseUrl$url',
        tags: (m['tags'] as List? ?? []).map((t) => t.toString()).toList(),
      );
    }).where((n) => n.title.isNotEmpty).toList();

    return HomeData(
      bannerUrls: banners,
      categories: categories,
      latestNovels: novels,
    );
  }

  /// 注入 HomeScreen 的 WebView 以提取首页数据
  static const extractScript = r"""
(function() {
  try {
    var banners = [];
    document.querySelectorAll('.swiper-slide img, .carousel-item img, .banner img').forEach(function(img) {
      var src = img.getAttribute('src') || img.getAttribute('data-src') || img.getAttribute('data-lazy') || '';
      if (src && src.length > 4 && banners.indexOf(src) === -1) banners.push(src);
    });

    var categories = [];
    document.querySelectorAll('.navbar-nav .nav-link, nav .nav-link').forEach(function(el) {
      var t = (el.innerText || '').trim();
      if (t && t.length < 20 && t.indexOf('\n') === -1 && categories.indexOf(t) === -1) categories.push(t);
    });

    var novels = [];
    var selectors = [
      '.col-xs-6.col-md-4.col-lg-3',
      '.col-6.col-md-4.col-lg-3',
      '.novel-item',
      '.book-item'
    ];
    var items = [];
    for (var i = 0; i < selectors.length; i++) {
      var found = document.querySelectorAll(selectors[i]);
      if (found.length > 0) { items = found; break; }
    }
    items.forEach(function(item) {
      var titleEl = item.querySelector('.novel-title, .title, h3, h4, .card-title');
      var coverEl = item.querySelector('img');
      var authorEl = item.querySelector('.author, .card-text');
      var linkEl = item.querySelector('a');
      var tagEls = item.querySelectorAll('.badge, .tag, .label');
      var title = titleEl ? (titleEl.innerText || '').trim() : '';
      if (!title && coverEl) title = coverEl.getAttribute('alt') || '';
      var cover = coverEl ? (coverEl.getAttribute('src') || coverEl.getAttribute('data-src') || '') : '';
      var author = authorEl ? (authorEl.innerText || '').trim() : '';
      var url = linkEl ? (linkEl.getAttribute('href') || '') : '';
      var tags = [];
      tagEls.forEach(function(t) { var txt = (t.innerText || '').trim(); if (txt) tags.push(txt); });
      if (title) novels.push({title: title, cover: cover, author: author, url: url, tags: tags});
    });

    FlutterBridge.postMessage(JSON.stringify({banners: banners, categories: categories, novels: novels}));
  } catch(e) {
    FlutterBridge.postMessage(JSON.stringify({banners: [], categories: [], novels: [], error: String(e)}));
  }
})();
""";
}
