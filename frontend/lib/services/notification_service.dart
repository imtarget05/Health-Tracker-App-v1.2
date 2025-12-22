import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:best_flutter_ui_templates/services/auth_storage.dart';
import 'package:best_flutter_ui_templates/services/backend_api.dart';

class NotificationService {
  /// Fetch notifications. Returns a list of maps; tries to parse `createdAt` into `createdAtParsed`.
  static Future<List<Map<String, dynamic>>> fetchNotifications() async {
    // Try to call the protected route GET /notifications/user/:userId if we have a backend JWT
    final jwt = AuthStorage.token;
    Uri uri;
    Map<String, String> headers = {'Accept': 'application/json'};

    if (jwt != null && jwt.isNotEmpty) {
      // Backend JWT available; derive userId from the JWT itself (token is authoritative)
      String? userId;
      try {
        final parts = jwt.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
          final Map<String, dynamic> parsed = json.decode(payload);
          // token payloads in this project use `userId` (generateToken), but also accept uid/sub
          userId = parsed['userId'] ?? parsed['uid'] ?? parsed['sub']?.toString();
        }
      } catch (_) {
        // ignore malformed token decode
      }

      // If we couldn't decode a userId from the JWT, as a fallback try the Firebase currentUser
      userId ??= FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        // We don't have an identifier for a protected GET; avoid calling a non-existent public route.
        // Let the caller receive a clear failure instead of hitting GET /notifications which may 404.
        throw Exception('No user id available for protected notifications request');
      }

      uri = Uri.parse('${BackendApi.baseUrl}/notifications/user/$userId');
      headers['Authorization'] = 'Bearer $jwt';
    } else {
      uri = Uri.parse('${BackendApi.baseUrl}/notifications');
    }

    http.Response response;
    try {
      response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 5));
    } catch (e) {
      // On network/timeouts: if this was an unauthenticated/public attempt rethrow; if it
      // was a protected attempt, bubble the error to caller so they can handle auth issues.
      rethrow;
    }

    // If protected route returned 401/403 or non-200, don't silently fall back to a non-existent public route.
    if (response.statusCode == 401 || response.statusCode == 403 || response.statusCode != 200) {
      throw Exception('Failed to load notifications: ${response.statusCode}');
    }
    final decoded = json.decode(response.body);
    List<Map<String, dynamic>> raw = [];
    if (decoded is List) {
      raw = decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    } else if (decoded is Map && decoded['notifications'] is List) {
      raw = (decoded['notifications'] as List).map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    }

    // Try to parse createdAt/timestamp fields into DateTime under 'createdAtParsed'
    for (var n in raw) {
      if (n['createdAtParsed'] != null) continue;
      final cand = n['createdAt'] ?? n['timestamp'] ?? n['time'];
      if (cand == null) continue;
      try {
        if (cand is int) {
          // epoch millis or seconds? assume millis if > 1e10
          if (cand > 10000000000) {
            n['createdAtParsed'] = DateTime.fromMillisecondsSinceEpoch(cand);
          } else {
            n['createdAtParsed'] = DateTime.fromMillisecondsSinceEpoch(cand * 1000);
          }
        } else if (cand is String) {
          n['createdAtParsed'] = DateTime.parse(cand);
        }
      } catch (_) {
        // ignore parse errors
      }
    }

    return raw;
  }
}

