import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  /// [expectedToken] 若不为 null，则消息 token 不匹配时抛 StaleTokenException
  static HomeData parseHomeJson(String raw, {int? expectedToken}) {
    if (raw.length > 500 * 1024) {
      throw FormatException('消息体过大（${raw.length} bytes），拒绝解析');
    }

    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('FlutterBridge 消息格式错误：根节点必须是对象');
    }

    // 支持带 token 的消息信封格式：{token, payload} 或旧格式直接解析
    final Map<String, dynamic> map;
    if (decoded.containsKey('payload') && decoded['payload'] is Map) {
      final token = decoded['token'];
      if (expectedToken != null && token != expectedToken) {
        throw const StaleTokenException();
      }
      map = decoded['payload'] as Map<String, dynamic>;
      // 打印调试信息（仅 debug 模式）
      final debug = decoded['_debug'] ?? map['_debug'];
      if (debug != null) {
        debugPrint('[NovelService] JS debug: $debug');
      }
    } else {
      map = decoded;
    }

    if (map['novels'] is! List) {
      throw const FormatException('FlutterBridge 消息缺少 novels 字段或类型错误');
    }

    return _parsePayload(map);
  }

  /// 单次循环解析，避免链式 map/where/toList 产生多个中间 List
  static HomeData _parsePayload(Map<String, dynamic> map) {
    // 解析 banners
    final banners = <String>[];
    final bannerRaw = map['banners'];
    if (bannerRaw is List) {
      for (final item in bannerRaw) {
        final s = item?.toString() ?? '';
        if (s.isNotEmpty) banners.add(s);
      }
    }

    // 解析 categories（最多 12 个）
    final categories = <String>[];
    final categoryRaw = map['categories'];
    if (categoryRaw is List) {
      for (final item in categoryRaw) {
        final s = item?.toString() ?? '';
        if (s.isNotEmpty) {
          categories.add(s);
          if (categories.length == 12) break;
        }
      }
    }

    // 解析 novels（单次循环，无中间 List）
    final novels = <Novel>[];
    for (final item in map['novels'] as List) {
      if (item is! Map) continue;
      final m = item as Map<String, dynamic>;
      final title = m['title']?.toString() ?? '';
      if (title.isEmpty) continue;

      final cover = m['cover']?.toString() ?? '';
      final url = m['url']?.toString() ?? '';

      final tags = <String>[];
      final tagsRaw = m['tags'];
      if (tagsRaw is List) {
        for (final tag in tagsRaw) {
          final s = tag?.toString() ?? '';
          if (s.isNotEmpty) tags.add(s);
        }
      }

      novels.add(Novel(
        title: title,
        coverUrl: cover.startsWith('http') ? cover : '$baseUrl$cover',
        author: m['author']?.toString() ?? '',
        url: url.startsWith('http') ? url : '$baseUrl$url',
        tags: tags,
      ));
    }

    return HomeData(
      bannerUrls: banners,
      categories: categories,
      latestNovels: novels,
    );
  }

  /// 生成带 [loadToken] 的 JS 抽取脚本
  /// 消息格式：{token, payload: {banners, categories, novels}}
  /// 替代固定 2s 延迟：脚本内轮询 DOM 就绪（最多 1500ms，每 120ms 检查一次）
  static String buildExtractScript(int loadToken) => """
(function() {
  var TOKEN = $loadToken;
  var deadline = Date.now() + 10000;  // 延长至 10s 等待动态渲染
  var attempts = 0;
  var MAX_ATTEMPTS = 80;  // 10000ms / 125ms = 80 次

  function collect() {
    var banners = [];
    var bannerSeen = Object.create(null);
    document.querySelectorAll('.swiper-slide img, .carousel-item img, .banner img').forEach(function(img) {
      var src = img.getAttribute('data-src') || img.getAttribute('data-original') || img.getAttribute('data-lazy') || img.getAttribute('src') || '';
      if (src && src.indexOf('data:') !== 0 && src.length > 10 && !bannerSeen[src]) { bannerSeen[src] = 1; banners.push(src); }
    });

    var categories = [];
    var catSeen = Object.create(null);
    document.querySelectorAll('.navbar-nav .nav-link, nav .nav-link').forEach(function(el) {
      var t = (el.innerText || '').trim();
      if (t && t.length < 20 && t.indexOf('\\n') === -1 && !catSeen[t]) { catSeen[t] = 1; categories.push(t); }
    });

    // 扩展选择器：覆盖更多可能的布局类名
    var selectors = [
      '.col-lg-3.col-md-4.col-sm-3.col-xs-6',
      '.col-xs-6.col-md-4.col-lg-3',
      '.col-6.col-md-4.col-lg-3',
      '.col-6.col-md-3',
      '.col-6.col-sm-4',
      '.col-6.col-md-4',
      '.novel-item',
      '.book-item',
      '.product-item',
      '.card',
      '[class*="col-"]'
    ];
    var selectorCounts = {};
    var items = [];
    var matchedSelector = '';
    for (var i = 0; i < selectors.length; i++) {
      var found = document.querySelectorAll(selectors[i]);
      selectorCounts[selectors[i]] = found.length;
      if (found.length > 2 && !matchedSelector) { items = found; matchedSelector = selectors[i]; }  // 至少3个才认为匹配
    }

    // 调试：输出第一个匹配卡片的 outerHTML（最多200字符）
    var firstHtml = items.length > 0 ? (items[0].outerHTML || '').substring(0, 300) : 'NO_ITEMS';
    var novels = [];
    items.forEach(function(item) {
      var titleEl = item.querySelector('.card-title a, .card-title h5, h5.card-title, .novel-title, .title, h3, h4, .text-truncate, p');
      var coverEl = item.querySelector('.card-img-tiles img, img');
      var authorEl = item.querySelector('.author, .card-text, small');
      var linkEl = item.querySelector('a.card-img-tiles, a');
      var tagEls = item.querySelectorAll('.badge, .tag, .label');
      // 标题优先从 card title 链接文字取，fallback 到 card div 的 title 属性
      var title = titleEl ? (titleEl.innerText || '').trim() : '';
      if (!title) {
        var cardEl = item.querySelector('.card[title]');
        if (cardEl) title = (cardEl.getAttribute('title') || '').trim();
      }
      if (!title && coverEl) title = coverEl.getAttribute('alt') || '';
      if (!title && linkEl) title = (linkEl.getAttribute('title') || '').trim();
      // 懒加载图片优先取 data-src/data-original，fallback 到 src
      var cover = coverEl ? (
        coverEl.getAttribute('data-src') ||
        coverEl.getAttribute('data-original') ||
        coverEl.getAttribute('data-lazy') ||
        coverEl.getAttribute('data-url') ||
        coverEl.getAttribute('src') || ''
      ) : '';
      // 过滤掉 base64 占位图（懒加载未触发时的默认值）
      if (cover && (cover.indexOf('data:') === 0 || cover.length < 10)) cover = '';
      // fallback：从 .main-img .lazyload 的 style background-image 提取封面（esjzone.cc 实际结构）
      if (!cover) {
        var lazyEl = item.querySelector('.main-img .lazyload, .main-img [style*="background"]');
        if (lazyEl) {
          var bgStyle = lazyEl.getAttribute('style') || '';
          var bgMatch = bgStyle.match(/url\(["']?([^"')]+)["']?\)/);
          if (bgMatch) cover = bgMatch[1];
        }
      }
      // fallback：从父元素或 <a> 的 style background-image 提取封面
      if (!cover) {
        var bgEl = item.querySelector('[style*="background"]') || item;
        var style = bgEl.getAttribute('style') || '';
        var bgMatch2 = style.match(/url\(["']?([^"')]+)["']?\)/);
        if (bgMatch2) cover = bgMatch2[1];
      }
      // fallback：从 <a> 标签 data-bg / data-cover 属性提取
      if (!cover && linkEl) {
        cover = linkEl.getAttribute('data-bg') || linkEl.getAttribute('data-cover') || linkEl.getAttribute('data-src') || '';
      }
      var author = authorEl ? (authorEl.innerText || '').trim() : '';
      var url = linkEl ? (linkEl.getAttribute('href') || '') : '';
      var tags = [];
      tagEls.forEach(function(t) { var txt = (t.innerText || '').trim(); if (txt) tags.push(txt); });
      if (title) novels.push({title: title, cover: cover, author: author, url: url, tags: tags});
    });

    return {banners: banners, categories: categories, novels: novels, matchedSelector: matchedSelector, selectorCounts: selectorCounts, firstHtml: firstHtml};
  }

  function post(payload) {
    FlutterBridge.postMessage(JSON.stringify({token: TOKEN, payload: payload}));
  }

  function attempt() {
    try {
      var data = collect();
      var hasContent = data.novels.length > 0 || data.categories.length > 2;
      var timedOut = Date.now() >= deadline || attempts >= MAX_ATTEMPTS;

      if (hasContent || timedOut) {
        // 调试信息：帮助定位选择器问题
        // 采集页面前10个元素的class，帮助定位选择器
        var firstClasses = [];
        var allEls = document.querySelectorAll('section > div, main > div, .container > div, .container-fluid > div, .row > div');
        for (var fi = 0; fi < Math.min(allEls.length, 5); fi++) {
          firstClasses.push(allEls[fi].className);
        }
        data._debug = {
          attempts: attempts,
          timedOut: timedOut,
          bodyClasses: document.body ? document.body.className : '',
          novelCount: data.novels.length,
          matchedSelector: data.matchedSelector,
          selectorCounts: JSON.stringify(data.selectorCounts),
          sampleClasses: firstClasses.join(' | '),
          firstHtml: data.firstHtml
        };
        post(data);
        return;
      }
      attempts++;
      setTimeout(attempt, 125);
    } catch(e) {
      post({banners: [], categories: [], novels: [], error: String(e)});
    }
  }

  attempt();
})();
""";
}

/// extractScript 返回过期 token 时抛出此异常，调用方可安全忽略
class StaleTokenException implements Exception {
  const StaleTokenException();
  @override
  String toString() => 'StaleTokenException: load token mismatch, response discarded';
}
