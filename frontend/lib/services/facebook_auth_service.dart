import 'dart:convert';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'backend_api.dart';

class FacebookAuthService {
  // Returns backend response map or throws
  Future<Map<String, dynamic>?> signInToBackend(String backendBaseUrl) async {
    // Trigger Facebook login
    final LoginResult result = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
    );

    // Log full result for debugging (status, message, accessToken shape)
    try {
      // ignore: avoid_print
      print('facebookAuth: result.status=${result.status}');
      // ignore: avoid_print
      print('facebookAuth: result.message=${result.message}');
      // accessToken may be null when status != success
      // ignore: avoid_print
      print('facebookAuth: accessToken=${result.accessToken}');
    } catch (_) {}

    if (result.status != LoginStatus.success) {
      final msg = result.message ?? result.status.toString();
      throw Exception('Facebook login failed: $msg');
    }

    final accessToken = result.accessToken!;

    // defensive: different versions expose different property names
    String? tokenValue;
    try {
      final dyn = accessToken as dynamic;
      tokenValue = dyn.token ?? dyn.tokenString ?? dyn.accessToken;
    } catch (_) {
      tokenValue = null;
    }

    if (tokenValue == null) {
      try {
        final dyn = accessToken as dynamic;
        if (dyn.toJson != null) {
          final json = dyn.toJson() as Map<String, dynamic>;
          tokenValue = json['token'] ?? json['accessToken'] ?? json['tokenString'];
        }
      } catch (_) {
        // ignore
      }
    }

    if (tokenValue == null) {
      throw Exception('Unable to extract Facebook access token');
    }

    // POST to backend /auth/facebook
    final uri = Uri.parse('$backendBaseUrl/auth/facebook');
    final resp = await http.post(uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'accessToken': tokenValue}));

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    try {
      final err = jsonDecode(resp.body);
      final msg = err is Map && err.containsKey('message') ? err['message'] : resp.body;
      throw Exception('Backend Facebook auth failed: ${resp.statusCode} $msg');
    } catch (_) {
      throw Exception('Backend Facebook auth failed: ${resp.statusCode} ${resp.body}');
    }
  }
}
