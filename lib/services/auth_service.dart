import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyCookie = 'esj_cookie';
  static const _keyLoggedIn = 'esj_logged_in';

  // O2: 缓存 SharedPreferences 实例，避免每次调用重复解析平台通道
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// 在 main() 中调用，与应用启动并行预热 SharedPreferences
  static void prime() {
    _getPrefs().ignore();
  }

  /// 登录成功标记（用于 HttpOnly Cookie 场景，凭证由 WebView 自动管理）
  static Future<void> markLoggedIn() async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyLoggedIn, true);
  }

  static Future<void> saveCookie(String cookie) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyCookie, cookie);
  }

  static Future<String?> getCookie() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyCookie);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_keyLoggedIn) == true;
  }

  static Future<void> logout() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyCookie);
    await prefs.remove(_keyLoggedIn);
    // 清除缓存，下次重新加载
    _prefs = null;
  }
}
