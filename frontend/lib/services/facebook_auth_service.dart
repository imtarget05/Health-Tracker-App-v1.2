import 'dart:convert';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

class FacebookAuthService {
  // Returns backend response map or throws
  Future<Map<String, dynamic>?> signInToBackend(String backendBaseUrl) async {
    // Trigger Facebook login. Use webOnly login behavior on iOS to avoid LimitedToken
    // which can be returned by native flows when the app is not public or permissions
    // are restricted. Web flow normally returns a full user access token (EAA...).
    // If you prefer native behavior on Android, you can adjust per-platform logic.
    // Try multiple login behaviors to increase chance of receiving a full
    // Facebook user access token (EAA...). On iOS simulators the plugin may
    // return a LimitedToken (id_token) for some behaviors; try nativeWithFallback
    // first, then webOnly as fallback.
    LoginResult result = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
      loginBehavior: LoginBehavior.webOnly,
    );

    try {
      final behaviors = [LoginBehavior.nativeWithFallback, LoginBehavior.webOnly];
      for (final behavior in behaviors) {
        // If the first call already succeeded, break early
        if (result.status == LoginStatus.success) break;

        // Attempt with next behavior
        // ignore: avoid_print
        print('facebookAuth: trying loginBehavior=$behavior');
        final r = await FacebookAuth.instance.login(
          permissions: ['email', 'public_profile'],
          loginBehavior: behavior,
        );
        // ignore: avoid_print
        print('facebookAuth: result for $behavior = ${r.status}');
        if (r.status == LoginStatus.success) {
          result = r;
          break;
        }
      }
    } catch (e) {
      // ignore and continue with whatever `result` we have
      // ignore: avoid_print
      print('facebookAuth: error while trying login behaviors: $e');
    }

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

    // Force-use the explicit `token` property when available (flutter_facebook_auth exposes `accessToken.token`).
    String? tokenValue;
    try {
      // Debug: print the full accessToken object shape (masked sensitive fields)
      try {
        final dyn = accessToken as dynamic;
        if (dyn != null) {
          Map<String, dynamic>? asJson;
          try {
            asJson = dyn.toJson() as Map<String, dynamic>?;
          } catch (_) {
            // some platform implementations may not expose toJson
            asJson = null;
          }

          if (asJson != null) {
            String maskField(String? s) {
              if (s == null) return '';
              if (s.length <= 16) return s;
              return '${s.substring(0,8)}...${s.substring(s.length-8)}';
            }

            final shown = asJson.map((k, v) => MapEntry(k, v is String ? maskField(v) : v));
            // ignore: avoid_print
            print('facebookAuth: accessToken.toJson()=${shown}');
          }
        }
      } catch (_) {}
      final dyn = accessToken as dynamic;
      // Primary: explicit token property
      tokenValue = dyn.token != null ? dyn.token.toString() : null;
      // Fallbacks (older shapes)
      if (tokenValue == null) tokenValue = dyn.tokenString ?? dyn.accessToken;
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

    // DEBUG: print raw token in debug builds only so developer can copy it for
    // debug_token checks. Remove this before releasing to production.
    if (kDebugMode) {
      // ignore: avoid_print
      print('facebookAuth: RAW tokenValue=${tokenValue}');
    }

    // If token looks like a JWT (id_token) reject it here; we require a user access token.
    final looksLikeJwt = tokenValue.startsWith('eyJ');
    final looksLikeEAA = tokenValue.startsWith('EAA');

    if (looksLikeJwt) {
      // We received an id_token/JWT instead of a user access token.
      // In production you should use a Facebook user access token (EAA...).
      // For development the backend has a dev-only path to accept and decode
      // id_tokens; send the token to the server for development testing.
      // Log a clear warning so developer sees this behavior.
      // ignore: avoid_print
      print('facebookAuth: warning received id_token/JWT from plugin; sending to backend for dev-only handling');
    }

    if (!looksLikeEAA) {
      // Not starting with EAA — still possible but warn. We'll still send it because other token shapes may exist on some platforms,
      // but log and allow the backend to reject if invalid. (This keeps compatibility on web where tokens can differ.)
      // ignore: avoid_print
      print('facebookAuth: warning token does not start with EAA; sending anyway for backend verification.');
    }

    // Prefer the explicit token property when available and mask for logs
    try {
      if (tokenValue == null) {
        // accessToken likely has `token` property
        try {
          tokenValue = (accessToken as dynamic).token ?? (accessToken as dynamic).tokenString ?? (accessToken as dynamic).accessToken;
        } catch (_) {
          // ignore
        }
      }

      String mask(String t) {
        if (t == null) return '';
        if (t.length <= 16) return t;
        return '${t.substring(0,8)}...${t.substring(t.length-8)}';
      }

      final len = tokenValue?.length ?? 0;
      final looksLikeEAA = tokenValue != null && tokenValue.startsWith('EAA');
      // ignore: avoid_print
      print('facebookAuth: tokenValue=${tokenValue != null ? mask(tokenValue) : '<null>'} length=$len looksLikeEAA=$looksLikeEAA');
    } catch (_) {}

    // POST to backend /auth/facebook
    final uri = Uri.parse('$backendBaseUrl/auth/facebook');
    // If token looks like JWT, we will try the backend path, but primary flow below
    // will try to sign in the user into Firebase client-side using the plugin result.

    // Ensure Firebase client initialized
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (_) {}

    // Prefer using the plugin's accessToken to sign in with Firebase
    try {
      final accessTokenForFirebase = tokenValue;
      // Build Facebook credential for Firebase
      final facebookCredential = FacebookAuthProvider.credential(accessTokenForFirebase!);
      // Sign in to Firebase with the Facebook credential
      final userCred = await FirebaseAuth.instance.signInWithCredential(facebookCredential);

      // Ensure Firestore profile exists with verbose logging for debugging
      try {
        final db = FirebaseFirestore.instance;
        final uid = userCred.user?.uid;
        // ignore: avoid_print
        print('FacebookAuthService: firebase signInWithCredential returned uid=$uid, email=${userCred.user?.email}');
        if (uid != null) {
          final userDoc = db.collection('users').doc(uid);
          final docPath = userDoc.path;
          // ignore: avoid_print
          print('FacebookAuthService: checking user doc at $docPath');
          final snap = await userDoc.get();
          // ignore: avoid_print
          print('FacebookAuthService: user doc exists=${snap.exists}');
          if (!snap.exists) {
            final profile = {
              'uid': uid,
              'email': userCred.user?.email ?? '',
              'fullName': userCred.user?.displayName ?? '',
              'profilePic': userCred.user?.photoURL ?? '',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
              'provider': 'facebook',
              'providerId': userCred.user?.uid,
            };
            // ignore: avoid_print
            print('FacebookAuthService: creating user profile with payload=${profile}');
            try {
              await userDoc.set(profile);
              // ignore: avoid_print
              print('FacebookAuthService: successfully wrote user profile to $docPath');
            } catch (writeErr, stack) {
              // ignore: avoid_print
              print('FacebookAuthService: failed to write user profile to $docPath: $writeErr');
              // ignore: avoid_print
              print(stack);
            }
          }
        }
      } catch (e, stack) {
        // non-fatal; continue but log stack trace for debugging
        // ignore: avoid_print
        print('FacebookAuthService: failed to create client-side Firestore profile: $e');
        // ignore: avoid_print
        print(stack);
      }

      // Get Firebase idToken and pass to backend login to get backend JWT
      final firebaseIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (firebaseIdToken == null) {
        return {
          'token': null,
          'uid': FirebaseAuth.instance.currentUser?.uid,
          'email': FirebaseAuth.instance.currentUser?.email,
        };
      }

      final resp = await http.post(Uri.parse('$backendBaseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'}, body: jsonEncode({'idToken': firebaseIdToken}));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }

      return {
        'token': null,
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'email': FirebaseAuth.instance.currentUser?.email,
      };
    } catch (e) {
      // Fallback: send token directly to backend (dev path)
      final body = {
        'accessToken': tokenValue,
        'tokenType': looksLikeJwt ? 'id_token' : 'access_token',
      };
      final resp = await http.post(uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body));

      // Debug: log backend response for troubleshooting
      // ignore: avoid_print
      print('FacebookAuthService: backend /auth/facebook POST status=${resp.statusCode}');
      try {
        // ignore: avoid_print
        print('FacebookAuthService: backend /auth/facebook body=${resp.body}');
      } catch (_) {}

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
}
