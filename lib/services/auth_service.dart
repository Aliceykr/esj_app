import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyCookie = 'esj_cookie';
  static const _keyLoggedIn = 'esj_logged_in';

  /// 登录成功标记（用于 HttpOnly Cookie 场景，凭证由 WebView 自动管理）
  static Future<void> markLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
  }

  static Future<void> saveCookie(String cookie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCookie, cookie);
  }

  static Future<String?> getCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCookie);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLoggedIn) == true;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCookie);
    await prefs.remove(_keyLoggedIn);
  }
}
