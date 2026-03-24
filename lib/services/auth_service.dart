import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyCookie = 'esj_cookie';

  static Future<void> saveCookie(String cookie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCookie, cookie);
  }

  static Future<String?> getCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCookie);
  }

  static Future<bool> isLoggedIn() async {
    final cookie = await getCookie();
    if (cookie == null || cookie.isEmpty) return false;
    // 检查关键登录 Cookie 是否存在
    return cookie.contains('ews_token') && cookie.contains('ews_key');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCookie);
  }
}
