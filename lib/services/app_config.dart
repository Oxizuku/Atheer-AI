import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const _urlKey = 'atheer_backend_url';
  static const _accessKey = 'atheer_access_code';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<String> getBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_urlKey) ?? '').trim().replaceAll(RegExp(r'/+$'), '');
  }

  static Future<String> getAccessCode() async =>
      (await _secureStorage.read(key: _accessKey) ?? '').trim();

  static Future<void> save({required String backendUrl, required String accessCode}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, backendUrl.trim().replaceAll(RegExp(r'/+$'), ''));
    await _secureStorage.write(key: _accessKey, value: accessCode.trim());
  }
}
