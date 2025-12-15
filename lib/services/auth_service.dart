import 'package:flutter/foundation.dart';
import 'api_client.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  Future<Map<String, dynamic>> register({required String fullName, required String email, required String password, String? phone}) async {
    final payload = {
      'fullName': fullName,
      'email': email,
      'password': password,
      if (phone != null) 'phone': phone,
    };
    return ApiClient.instance.post('/auth/register', payload);
  }

  Future<Map<String, dynamic>> loginWithEmailPassword({required String email, required String password}) async {
    return ApiClient.instance.post('/auth/login-email', {
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> me() async {
    return ApiClient.instance.get('/auth/me');
  }
}
