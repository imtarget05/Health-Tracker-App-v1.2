import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

  static Future<Map<String, dynamic>?> predict(String imagePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/predict'),
      );

      final file = await http.MultipartFile.fromPath('file', imagePath);
      request.files.add(file);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to predict: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
