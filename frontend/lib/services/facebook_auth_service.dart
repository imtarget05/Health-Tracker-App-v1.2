import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
// Debug-only storage cleanup helpers
import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:best_flutter_ui_templates/services/event_bus.dart';
import 'dart:math';

class FacebookAuthService {
  String _randomNonce([int length = 32]) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
  // Clear commonly-used auth keys safely
  // Returns backend response map or throws
  Future<Map<String, dynamic>?> signInToBackend(String backendBaseUrl) async {
  final requestId = DateTime.now().microsecondsSinceEpoch.toString();
  final nonce = _randomNonce();
    // Trigger Facebook login
    // Ensure any previous auth state is cleared to avoid returning an
    // app JWT instead of a fresh Facebook access token.
    try {
      // Minimal, safe cleanup BEFORE invoking the Facebook SDK login.
      // This runs in all modes to avoid the SDK returning an unrelated
      // app JWT that might be stored under common keys.
      try {
        final storage = FlutterSecureStorage();
        final keysToClear = ['app_jwt', 'jwt', 'access_token', 'auth_token', 'firebase_token', 'fb_access_token'];
        for (final k in keysToClear) {
          await storage.delete(key: k).catchError((_) {});
        }
      } catch (_) {}

      try {
        final prefs = await SharedPreferences.getInstance();
        final keysToClear = ['app_jwt', 'jwt', 'access_token', 'auth_token', 'firebase_token', 'fb_access_token'];
        for (final k in keysToClear) {
          if (prefs.containsKey(k)) await prefs.remove(k);
        }
      } catch (_) {}

      try {
        if (Hive.isBoxOpen('session')) {
          final box = Hive.box('session');
          final keysToClear = ['app_jwt', 'jwt', 'access_token', 'auth_token', 'firebase_token', 'fb_access_token'];
          for (final k in keysToClear) {
            if (box.containsKey(k)) box.delete(k);
          }
        }
      } catch (_) {}

      await FacebookAuth.instance.logOut();
    } catch (_) {}
    try {
      // Optional: if using FirebaseAuth locally, clear it as well.
      // Import moved to top if needed at build time.
      // await FirebaseAuth.instance.signOut();
    } catch (_) {}

    final LoginResult result = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
      loginBehavior: LoginBehavior.webOnly,
    );

    // Log full result for debugging (status, message, accessToken shape)
    try {
      if (kDebugMode) {
        debugPrint('facebookAuth: result.status=${result.status}');
        debugPrint('facebookAuth: result.message=${result.message}');
        debugPrint('facebookAuth: accessToken=${result.accessToken}');
      }
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

    // Sanitize token: trim whitespace/newlines and strip surrounding quotes
    try {
      tokenValue = tokenValue.trim();
      if (tokenValue.startsWith('"') && tokenValue.endsWith('"') && tokenValue.length > 1) {
        tokenValue = tokenValue.substring(1, tokenValue.length - 1);
      }
      tokenValue = tokenValue.replaceAll(RegExp(r"[\n\r]"), '');
    } catch (_) {}
        // tracking: LoginTracking.enabled, // Removed unsupported tracking parameter
  // Promote to non-nullable local variable for null-safety and consistent use
  final String token = tokenValue!;

    // DEBUG: print and validate token shape in debug mode so we can
    // catch 'LimitedToken' / object-wrapper issues early.
    try {
      if (kDebugMode) {
        // Mask token for logs but show length for quick checks.
        final masked = token.length > 10 ? '${token.substring(0,6)}...${token.substring(token.length-4)}' : token;
        final bytes = utf8.encode(token);
        final digest = crypto.sha256.convert(bytes).toString();
        debugPrint('facebookAuth: tokenValue (masked)=$masked length=${token.length}');
        debugPrint('facebookAuth: tokenValueSha256=$digest');
        // Basic heuristic: Facebook access tokens usually start with 'EA' (not 'eyJ')
        // and are not JWTs (JWTs contain two dots). If we detect a JWT here it
        // likely means the app is sending its own backend JWT instead of the
        // Facebook access token (causes Bad signature on server). Fail early.
        final looksLikeJwt = token.startsWith('eyJ') || (token.split('.').length == 3);
        if (looksLikeJwt) {
          // Limited Login token (JWT-like). This is expected on iOS when
          // Limited Login is enabled. Our backend now supports verifying
          // this JWT via JWKS, so we allow it.
          debugPrint('facebookAuth: token looks like a JWT (Limited Login). Sending to backend JWT verifier.');
        }
      }
      // Basic validation: token should be a non-empty string without whitespace.
      // Basic validation: token should be a non-empty string without whitespace.
      if (token.trim().isEmpty || token.contains(RegExp(r"\s")) || token.length < 20) {
        throw Exception('Extracted Facebook token looks invalid (too short or contains spaces)');
      }
    } catch (e) {
      // Surface a clear message upstream so UI shows helpful error.
      throw Exception('Facebook token extraction/validation failed: ${e.toString()}');
    }

    // POST to backend /auth/facebook
    final uri = Uri.parse('$backendBaseUrl/auth/facebook');
    // Compute token hash for debug comparison with backend logs.
    String? tokenSha;
    try {
      final bytes = utf8.encode(token);
      tokenSha = crypto.sha256.convert(bytes).toString();
    } catch (_) {
      tokenSha = null;
    }

    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
  'X-Request-Id': requestId,
    };
    if (tokenSha != null) {
      headers['X-Client-Token-Sha256'] = tokenSha;
    }

    Future<http.Response> postToken(String tokenToSend) {
  final body = jsonEncode({'accessToken': tokenToSend, 'nonce': nonce});
      return http.post(uri, headers: headers, body: body);
    }

  final resp = await postToken(token);

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      EventBus.instance.emitSuccess('Đăng nhập thành công.');
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

          debugPrint('facebookAuth: token looks like a JWT (Limited Login). Will send to backend Limited Login verifier.');
    try {
      final err = jsonDecode(resp.body);
      final msg = err is Map && err.containsKey('message') ? err['message'] : resp.body;
      final details = err is Map && err.containsKey('details') ? err['details'] : null;
      EventBus.instance.emitError('Đăng nhập thất bại.');
      if (details != null) {
        throw Exception('Backend Facebook auth failed: ${resp.statusCode} $msg ${jsonEncode(details)}');
      }
      throw Exception('Backend Facebook auth failed: ${resp.statusCode} $msg');
    } catch (_) {
      EventBus.instance.emitError('Đăng nhập thất bại.');
      throw Exception('Backend Facebook auth failed: ${resp.statusCode} ${resp.body}');
    }
  }
}
