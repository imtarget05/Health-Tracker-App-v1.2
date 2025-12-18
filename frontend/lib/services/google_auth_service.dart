import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Simple Google Sign-In -> Backend helper
///
/// Usage:
/// final svc = GoogleAuthService();
/// final result = await svc.signInToBackend('http://127.0.0.1:5001');
/// if (result != null) {
///   // result contains backend user object and token
/// }
class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Sign in with Google and send Google ID token to backend `/auth/google`.
  /// Returns decoded JSON response from backend on success.
  Future<Map<String, dynamic>?> signInToBackend(String backendBaseUrl) async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // user cancelled

    final googleAuth = await account.authentication;
    final idToken = googleAuth.idToken;
  final accessToken = googleAuth.accessToken;
    if (idToken == null) {
      throw Exception('Failed to obtain Google idToken');
    }

    final resp = await http.post(
      Uri.parse('$backendBaseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (resp.statusCode == 200) {
      // Return backend response plus the google idToken/accessToken so the
      // caller can sign in the Firebase client SDK locally.
      final backend = jsonDecode(resp.body) as Map<String, dynamic>;
      return {
        'backend': backend,
        'idToken': idToken,
        'accessToken': accessToken,
      };
    }

    throw Exception('Backend Google auth failed: ${resp.statusCode} ${resp.body}');
  }

  /// Optional: sign out from Google on device
  Future<void> signOut() => _googleSignIn.signOut();
}
