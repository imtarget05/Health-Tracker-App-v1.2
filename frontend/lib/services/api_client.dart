import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  // Configure base URL via env or fallback
  // For web debug, you may need your machine IP for device emulators.
  static final String _baseUrl = dotenv.env['BACKEND_URL'] ?? 'http://localhost:8080';

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {Map<String, String>? headers}) async {
    final h = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    final b = body is String ? body : json.encode(body);
    final resp = await http.post(_uri(path), headers: h, body: b);

    final text = resp.body.isNotEmpty ? resp.body : '{}';
    final data = json.decode(text);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return data as Map<String, dynamic>;
    }
    throw ApiException(resp.statusCode, data is Map<String, dynamic> ? (data['message']?.toString() ?? 'Request failed') : 'Request failed');
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers}) async {
    final resp = await http.get(_uri(path), headers: headers);
    final text = resp.body.isNotEmpty ? resp.body : '{}';
    final data = json.decode(text);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return data as Map<String, dynamic>;
    }
    throw ApiException(resp.statusCode, data is Map<String, dynamic> ? (data['message']?.toString() ?? 'Request failed') : 'Request failed');
  }

  static Future<http.Response> put(String path, {Map<String, String>? headers, Object? body, Map<String, dynamic>? query}) {
    final h = {
      'Content-Type': 'application/json',
      ...?headers,
    };
    final b = body is String ? body : json.encode(body ?? {});
    return http.put(_uri(path, query), headers: h, body: b);
  }

  static Future<http.Response> delete(String path, {Map<String, String>? headers, Map<String, dynamic>? query}) {
    return http.delete(_uri(path, query), headers: headers);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}
