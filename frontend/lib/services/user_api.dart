import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class UserApi {
  // Set your backend base URL in env (REACT/express) or hardcode for now
  static String baseUrl = const String.fromEnvironment('BACKEND_URL', defaultValue: 'https://your-backend.example.com');

  /// Calls GET /users/me with Firebase ID token in Authorization: Bearer <token>
  static Future<Map<String, dynamic>?> fetchMe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken();
    final uri = Uri.parse('\$baseUrl/users/me'.replaceFirst('\u007f\$', ''));
    try {
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('UserApi.fetchMe error: $e');
    }
    return null;
  }
}
