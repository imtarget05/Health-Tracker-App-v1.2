// Simplified AuthService - chỉ dùng Firebase, backend chỉ cho OTP và admin features
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  // ✅ CẬU HÌNH BACKEND URL - chỉ dùng cho OTP và các tính năng đặc biệt
  static const String baseUrl = 'http://localhost:3000/api/auth'; // Local
  // static const String baseUrl = 'http://your-domain.com/api/auth'; // Production

  // ✅ GỬI OTP LOGIN (backend API cho OTP)
  Future<Map<String, dynamic>> sendLoginOTP(String email) async {
    try {
      debugPrint('📧 Sending OTP to: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/send-login-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);
      debugPrint('📡 OTP response: ${response.statusCode}');

      return data;
    } catch (e) {
      debugPrint('❌ OTP send error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ✅ XÁC THỰC OTP
  Future<Map<String, dynamic>> verifyLoginOTP(String email, String otp) async {
    try {
      debugPrint('🔐 Verifying OTP for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/verify-login-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'otp': otp}),
      );

      final data = json.decode(response.body);
      debugPrint('📡 OTP verify response: ${response.statusCode}');

      return data;
    } catch (e) {
      debugPrint('❌ OTP verify error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ✅ QUÊN MẬT KHẨU
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      debugPrint('📧 Forgot password for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);
      debugPrint('📡 Forgot password response: ${response.statusCode}');

      return data;
    } catch (e) {
      debugPrint('❌ Forgot password error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ✅ RESET PASSWORD VỚI OTP
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
  }) async {
    try {
      debugPrint('🔄 Resetting password for: $email');

      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'otp': otp,
        }),
      );

      final data = json.decode(response.body);
      debugPrint('📡 Reset password response: ${response.statusCode}');

      return data;
    } catch (e) {
      debugPrint('❌ Reset password error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ✅ VERIFY FIREBASE TOKEN với backend (optional - để backend có thể validate user)
  Future<Map<String, dynamic>> verifyFirebaseToken(String? idToken) async {
    if (idToken == null) {
      debugPrint('⚠️ idToken is null, skipping verification');
      return {'success': false, 'message': 'No token provided'};
    }

    try {
      debugPrint('🔐 Verifying Firebase token with backend');

      final response = await http.post(
        Uri.parse('$baseUrl/verify-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
      );

      final data = json.decode(response.body);
      debugPrint('📡 Token verify response: ${response.statusCode}');

      return data;
    } catch (e) {
      debugPrint('❌ Token verification error: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ✅ KIỂM TRA KẾT NỐI BACKEND
  Future<bool> checkBackendConnection() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl.replaceAll('/auth', '/health')),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Backend connection check failed: $e');
      return false;
    }
  }
}
