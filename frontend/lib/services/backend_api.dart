import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class BackendApi {
  // Read BASE_API_URL from .env via flutter_dotenv; fallback to localhost
  static String get baseUrl {
    final envUrl = dotenv.env['BASE_API_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    // Sensible defaults for dev
    if (kIsWeb) return 'http://localhost:5001';
    if (Platform.isAndroid) return 'http://10.0.2.2:5001'; // Android emulator
    if (Platform.isIOS) return 'http://127.0.0.1:5001';    // iOS simulator
    return 'http://localhost:5001';
  }

  // Simple health check
  static Future<Map<String, dynamic>> healthCheck() async {
    final url = Uri.parse('$baseUrl/api/health');
    final resp = await http.get(url, headers: {
      'Accept': 'application/json',
    });

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception('Health check failed: ${resp.statusCode}');
  }

  // Example: get auth/me (requires Authorization: Bearer <jwt> or cookie)
  static Future<Map<String, dynamic>> getMe({required String jwt}) async {
    final url = Uri.parse('$baseUrl/auth/me');
    final resp = await http.get(url, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $jwt',
    });

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception('getMe failed: ${resp.statusCode} ${resp.body}');
  }

  // Example: post water log
  static Future<Map<String, dynamic>> postWater({required String jwt, required int amountMl}) async {
    final url = Uri.parse('$baseUrl/water');
    final resp = await http.post(url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'amountMl': amountMl}));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('postWater failed: ${resp.statusCode} ${resp.body}');
  }

  // Multipart file upload helper for /upload or /foods/scan
  // filePath: local path to file, fieldName: 'file' (backend expects 'file')
  // extraFields: optional form fields like mealType
  static Future<Map<String, dynamic>> uploadFile({
    required String jwt,
    required String endpointPath,
    required String filePath,
    String fieldName = 'file',
    Map<String, String>? extraFields,
  }) async {
    final uri = Uri.parse('$baseUrl$endpointPath');
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $jwt';
    request.headers['Accept'] = 'application/json';

    if (extraFields != null) {
      request.fields.addAll(extraFields);
    }

    final file = await http.MultipartFile.fromPath(fieldName, filePath);
    request.files.add(file);

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception('uploadFile failed: ${resp.statusCode} ${resp.body}');
  }

  // Placeholder: loginWithToken
  // Frontend typically uses Firebase client SDK to get an idToken, then sends it to
  // POST /auth/login on the backend. Implement according to your auth flow.
  static Future<Map<String, dynamic>> loginWithIdToken({required String idToken}) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final resp = await http.post(url, headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    }, body: jsonEncode({'idToken': idToken}));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      // return full parsed body so caller can extract backend JWT
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    // try to parse backend error message and throw a readable exception
    try {
      final err = jsonDecode(resp.body);
      final msg = err is Map && err.containsKey('message') ? err['message'] : resp.body;
      throw Exception('loginWithIdToken failed: $msg');
    } catch (_) {
      throw Exception('loginWithIdToken failed: ${resp.statusCode} ${resp.body}');
    }
  }

  // POST /ai/chat - send message and optional history to backend AI coach
  static Future<Map<String, dynamic>> postAiChat({required String jwt, required String message, List<Map<String, String>>? history}) async {
    final url = Uri.parse('$baseUrl/ai/chat');
    final body = <String, dynamic>{'message': message};
    if (history != null) body['history'] = history;

    final resp = await http.post(url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode(body));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    throw Exception('postAiChat failed: ${resp.statusCode} ${resp.body}');
  }

  // Signup via backend (/auth/register)
  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');
    final body = {
      'fullName': fullName,
      'email': email,
      'password': password,
      if (phone != null) 'phone': phone,
    };

    final resp = await http.post(url,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    // try to parse error message
    try {
      final err = jsonDecode(resp.body);
      throw Exception(err['message'] ?? resp.body);
    } catch (_) {
      throw Exception('signup failed: ${resp.statusCode} ${resp.body}');
    }
  }
}
