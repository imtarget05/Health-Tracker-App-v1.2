import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:best_flutter_ui_templates/services/auth_storage.dart';

class ApiService {
  // Backend upload endpoint that accepts multipart form 'file' and returns prediction JSON.
  // Backend mounts upload router at /upload (see backend/src/index.js)
  static const String baseUrl = 'http://127.0.0.1:5001';

  static Future<Map<String, dynamic>?> predict(String imagePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );

      final file = await http.MultipartFile.fromPath('file', imagePath);
      request.files.add(file);

      // If a backend JWT exists, forward it so backend can protect the route
      final jwt = AuthStorage.token;
      if (jwt != null && jwt.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $jwt';
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        // propagate backend error description if present
        String body = response.body;
        try {
          final parsed = json.decode(response.body);
          if (parsed is Map && parsed['message'] != null) body = parsed['message'];
        } catch (_) {}
        throw Exception('Failed to predict: ${response.statusCode} - $body');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
