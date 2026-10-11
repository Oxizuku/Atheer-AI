import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_config.dart';

class ResearchService {
  static Future<Map<String, dynamic>> search(String query) async {
    final baseUrl = await AppConfig.getBackendUrl();
    final accessCode = await AppConfig.getAccessCode();
    if (baseUrl.isEmpty || accessCode.isEmpty) {
      throw Exception('أكمل إعداد رابط الخادم ورمز الوصول أولًا.');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/api/research'),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'X-Atheer-Access-Code': accessCode,
      },
      body: jsonEncode(<String, dynamic>{'query': query}),
    ).timeout(const Duration(seconds: 90));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['error'] : null;
      throw Exception(message?.toString() ?? 'فشل البحث (${response.statusCode}).');
    }
    if (decoded is! Map<String, dynamic>) throw Exception('رد البحث غير مفهوم.');
    return decoded;
  }
}
