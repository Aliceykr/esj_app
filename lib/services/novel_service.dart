import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as htmlParser;
import '../models/novel.dart';
import 'auth_service.dart';

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
  static const _baseUrl = 'https://www.esjzone.cc';

  static Future<Map<String, String>> _headers() async {
    final cookie = await AuthService.getCookie() ?? '';
    return {
      'Cookie': cookie,
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
      'Referer': _baseUrl,
    };
  }

  static Future<HomeData> fetchHomePage() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/'),
      headers: await _headers(),
    );

    final doc = htmlParser.parse(response.body);

    // 解析分类导航
    final categories = <String>[];
    final navItems = doc.querySelectorAll('.navbar-nav .nav-item .nav-link');
    for (final item in navItems) {
      final text = item.text.trim();
      if (text.isNotEmpty && !text.contains('\n')) {
        categories.add(text);
      }
    }

    // 解析轮播图
    final bannerUrls = <String>[];
    final banners = doc.querySelectorAll('.swiper-slide img, .carousel-item img, .banner img');
    for (final img in banners) {
      final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
      if (src.isNotEmpty) bannerUrls.add(src);
    }

    // 解析最新更新小说列表
    final novels = <Novel>[];
    final items = doc.querySelectorAll('.col-xs-6.col-md-4.col-lg-3, .novel-item, .book-item');
    for (final item in items) {
      final titleEl = item.querySelector('.novel-title, .title, h3, h4, .card-title');
      final coverEl = item.querySelector('img');
      final authorEl = item.querySelector('.author, .card-text');
      final linkEl = item.querySelector('a');
      final tagEls = item.querySelectorAll('.badge, .tag, .label');

      final title = titleEl?.text.trim() ?? '';
      final cover = coverEl?.attributes['src'] ?? coverEl?.attributes['data-src'] ?? '';
      final author = authorEl?.text.trim() ?? '';
      final url = linkEl?.attributes['href'] ?? '';
      final tags = tagEls.map((e) => e.text.trim()).where((t) => t.isNotEmpty).toList();

      if (title.isNotEmpty) {
        novels.add(Novel(
          title: title,
          coverUrl: cover.startsWith('http') ? cover : '$_baseUrl$cover',
          author: author,
          url: url.startsWith('http') ? url : '$_baseUrl$url',
          tags: tags,
        ));
      }
    }

    return HomeData(
      bannerUrls: bannerUrls,
      categories: categories.take(10).toList(),
      latestNovels: novels,
    );
  }
}
