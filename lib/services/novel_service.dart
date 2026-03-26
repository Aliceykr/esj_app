import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as htmlparser;
import 'package:html/dom.dart';
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

  /// 解析 WebView outerHTML，返回首页数据。
  /// 不依赖 JS 框架执行，只要 HTML 响应体到达即可工作。
  static HomeData parseHomeHtml(String html) {
    final doc = htmlparser.parse(html);

    // debug：确认 DOM 内容是否存在
    debugPrint('[NovelService] body.class: ${doc.body?.className ?? "(null)"}');
    debugPrint('[NovelService] html.length: ${html.length}');
    debugPrint('[NovelService] html snippet: ${html.substring(0, min(2000, html.length))}');

    final banners = _parseBanners(doc);
    final categories = _parseCategories(doc);
    final novels = _parseNovels(doc);

    debugPrint('[NovelService] parsed: ${novels.length} novels, ${categories.length} cats, ${banners.length} banners');
    return HomeData(
      bannerUrls: banners,
      categories: categories,
      latestNovels: novels,
    );
  }

  static List<String> _parseBanners(Document doc) {
    final banners = <String>[];
    final seen = <String>{};
    for (final selector in [
      '.swiper-slide img',
      '.carousel-item img',
      '.banner img',
      '.slider img',
    ]) {
      for (final img in doc.querySelectorAll(selector)) {
        final src = img.attributes['data-src'] ??
            img.attributes['data-original'] ??
            img.attributes['data-lazy'] ??
            img.attributes['src'] ??
            '';
        if (src.isNotEmpty && !src.startsWith('data:') && src.length > 10 && seen.add(src)) {
          banners.add(src.startsWith('http') ? src : '$baseUrl$src');
        }
      }
      if (banners.isNotEmpty) break;
    }
    return banners;
  }

  static List<String> _parseCategories(Document doc) {
    final cats = <String>[];
    final seen = <String>{};
    for (final selector in [
      '.navbar-nav .nav-link',
      '.nav-pills .nav-item a',
      'nav .nav-link',
    ]) {
      for (final el in doc.querySelectorAll(selector)) {
        final t = el.text.trim();
        if (t.isNotEmpty && t.length <= 12 && !t.contains('\n') && seen.add(t)) {
          cats.add(t);
          if (cats.length == 12) break;
        }
      }
      if (cats.length > 2) break;
    }
    return cats;
  }

  static List<Novel> _parseNovels(Document doc) {
    final selectors = [
      '.col-lg-3',
      '.col-md-4',
      '.col-sm-6',
      '.col-6',
      '.novel-item',
      '.book-item',
      '.product-item',
      '.card',
    ];

    List<Element> items = [];
    String matchedSelector = '';
    for (final sel in selectors) {
      final found = doc.querySelectorAll(sel);
      debugPrint('[NovelService] selector $sel => ${found.length} items');
      if (found.length > 2) {
        items = found.toList();
        matchedSelector = sel;
        break;
      }
    }
    debugPrint('[NovelService] matched selector: $matchedSelector, items: ${items.length}');
    if (items.length > 1) {
      debugPrint('[NovelService] item[0] HTML: ${items[0].outerHtml.substring(0, min(600, items[0].outerHtml.length))}');
      debugPrint('[NovelService] item[1] HTML: ${items[1].outerHtml.substring(0, min(600, items[1].outerHtml.length))}');
    }

    final novels = <Novel>[];
    for (final item in items) {
      // 封面：esjzone.cc 的 .lazyload div 有两种形式：
      // 1. 视口内（已触发）：style="background-image: url(...);"
      // 2. 视口外（未触发）：data-src="https://..."
      var cover = '';
      final lazyEl = item.querySelector('.main-img .lazyload') ??
          item.querySelector('.lazyload');
      if (lazyEl != null) {
        // 优先取 data-src（原始 URL，不依赖 JS 触发）
        final dataSrc = lazyEl.attributes['data-src'] ??
            lazyEl.attributes['data-original'] ??
            lazyEl.attributes['data-lazy'] ??
            '';
        if (dataSrc.isNotEmpty && dataSrc.length > 10) {
          cover = dataSrc;
        } else {
          // fallback：从 style background-image 取（视口内已触发的）
          final style = lazyEl.attributes['style'] ?? '';
          final m = RegExp(r'url\(([^)]+)\)').firstMatch(style);
          if (m != null) {
            cover = m.group(1)!.replaceAll('"', '').replaceAll("'", '').trim();
          }
        }
      }
      // fallback：普通 img 标签
      if (cover.isEmpty) {
        final imgEl = item.querySelector('img');
        final src = imgEl?.attributes['data-src'] ??
            imgEl?.attributes['data-original'] ??
            imgEl?.attributes['src'] ??
            '';
        if (!src.startsWith('data:') && src.length > 10) cover = src;
      }

      // 已知占位图（esjzone.cc 用于无封面小说的默认图），视为无封面
      if (cover == 'https://i.pinimg.com/564x/86/1e/51/861e5157abc25f92f6b49af0f1465927.jpg') {
        cover = '';
      }

      // 链接
      final linkEl = item.querySelector('a.card-img-tiles') ??
          item.querySelector('a');
      final href = linkEl?.attributes['href'] ?? '';

      // 标题：优先 .card-title 内的 <a>，fallback 到 .card[title] 属性
      var title = item.querySelector('.card-title a, .card-title')?.text.trim() ?? '';
      if (title.isEmpty) {
        title = item.querySelector('.card[title]')?.attributes['title']?.trim() ?? '';
      }
      if (title.isEmpty) title = item.querySelector('h5, h4, h3')?.text.trim() ?? '';
      if (title.isEmpty) title = linkEl?.attributes['title']?.trim() ?? '';

      if (title.isEmpty) continue;

      // 作者
      final author = item.querySelector('.author, small')?.text.trim() ?? '';

      // 标签
      final tags = item.querySelectorAll('.badge, .tag, .label')
          .map((e) => e.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      novels.add(Novel(
        title: title,
        coverUrl: cover.startsWith('http') ? cover : (cover.isNotEmpty ? '$baseUrl$cover' : ''),
        author: author,
        url: href.startsWith('http') ? href : (href.isNotEmpty ? '$baseUrl$href' : ''),
        tags: tags,
      ));
    }
    return novels;
  }
}
