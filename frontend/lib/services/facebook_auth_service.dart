import 'dart:convert';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../firebase_options.dart';
import 'profile_sync_service.dart';

class FacebookAuthService {
  /// Sign in using Facebook and exchange the Firebase ID token with backend.
  /// Returns backend JSON on success or a structured error map.
  Future<Map<String, dynamic>?> signInToBackend(String backendBaseUrl) async {
    final uri = Uri.parse('$backendBaseUrl/auth/facebook');

    // Try plugin login with sensible fallback order (native first then web)
    LoginResult result = LoginResult(status: LoginStatus.failed);
  // Try web-only first (often returns a full access token in simulator/emulator),
  // then fallback to nativeWithFallback.
  final behaviors = [LoginBehavior.webOnly, LoginBehavior.nativeWithFallback];
    for (final behavior in behaviors) {
      try {
        if (kDebugMode) print('facebookAuth: trying loginBehavior=$behavior');
        final r = await FacebookAuth.instance.login(
          permissions: ['email', 'public_profile'],
          loginBehavior: behavior,
        );
        if (kDebugMode) print('facebookAuth: result for $behavior = ${r.status}');
        if (r.status == LoginStatus.success) {
          result = r;
          break;
        }
      } catch (e) {
        if (kDebugMode) print('facebookAuth: loginBehavior $behavior error: $e');
      }
    }

    // If plugin didn't return a success result, try reading last cached accessToken
    if (result.status != LoginStatus.success) {
      try {
        final cached = await FacebookAuth.instance.accessToken;
        if (cached != null) {
          if (kDebugMode) print('facebookAuth: found cached accessToken');
          result = LoginResult(status: LoginStatus.success, accessToken: cached);
        }
      } catch (_) {}
    }

    if (result.status != LoginStatus.success) {
      final msg = result.message ?? result.status.toString();
      return {'error': true, 'message': 'Facebook login failed: $msg'};
    }

    final accessTokenObj = result.accessToken;
    if (accessTokenObj == null) return {'error': true, 'message': 'No Facebook access token returned'};

    // Debug: log runtime type and toString() for investigation on devices where shape is unexpected
    if (kDebugMode) {
      try {
        print('facebookAuth: accessTokenObj.runtimeType=' + accessTokenObj.runtimeType.toString());
        print('facebookAuth: accessTokenObj.toString()=' + accessTokenObj.toString());
      } catch (e) {
        print('facebookAuth: failed to debug-print accessTokenObj: $e');
      }
    }

    // extract token string robustly from multiple possible shapes
    String? tokenValue;
    try {
      final dyn = accessTokenObj as dynamic;

      if (dyn == null) {
        tokenValue = null;
      } else {
        // 1) Common direct getters
        try {
          tokenValue = dyn.token ?? dyn.tokenString ?? dyn.accessToken ?? dyn.value ?? dyn.rawToken ?? dyn.access_token;
        } catch (_) {}

        // 2) If it's a Map-like object or has toJson, try those
        if (tokenValue == null) {
          try {
            // try to call toJson() if available
            final js = dyn.toJson != null ? dyn.toJson() : null;
            if (js is Map) {
              tokenValue = js['token'] ?? js['accessToken'] ?? js['access_token'] ?? js['value'];
            }
          } catch (_) {}
        }

        // 3) If it's a plain Map
        if (tokenValue == null && dyn is Map) {
          tokenValue = dyn['token'] ?? dyn['accessToken'] ?? dyn['access_token'] ?? dyn['value'];
        }

        // 4) Fallback: try to extract EAA... or eyJ... substring from toString()
        if (tokenValue == null) {
          try {
            final s = dyn.toString();
            if (s != null) {
              // find EAA... token
              final eaam = RegExp(r'(EAA[0-9A-Za-z-_]{10,})');
              final jwt = RegExp(r'(eyJ[0-9A-Za-z-_\.]{10,})');
              final m1 = eaam.firstMatch(s);
              final m2 = jwt.firstMatch(s);
              if (m1 != null) tokenValue = m1.group(1);
              else if (m2 != null) tokenValue = m2.group(1);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      if (kDebugMode) print('facebookAuth: token extraction error: $e');
      tokenValue = null;
    }

    if (tokenValue == null) {
      // include fallback info for debugging
      try {
        final cached = await FacebookAuth.instance.accessToken;
        if (cached != null && kDebugMode) {
          // Avoid referencing properties that may not exist on AccessToken across versions.
          // Print a safe diagnostic instead.
          print('facebookAuth: cached accessToken object present (${cached.toString()})');
        }
      } catch (_) {}
      return {'error': true, 'message': 'Unable to extract Facebook access token (plugin returned unexpected shape)'};
    }

    if (kDebugMode) {
      String mask(String t) {
        if (t.length <= 12) return t;
        return '${t.substring(0,6)}...${t.substring(t.length - 6)}';
      }
      // ignore: avoid_print
      print('facebookAuth: token=${mask(tokenValue)} len=${tokenValue.length}');
    }

    final looksLikeJwt = tokenValue.startsWith('eyJ');
    final looksLikeEAA = tokenValue.startsWith('EAA');
    // debug token expiry if available
    try {
      final cached = await FacebookAuth.instance.accessToken;
      if (cached != null && kDebugMode) {
        // Print safe info — avoid accessing platform-specific getters
        print('facebookAuth: cached accessToken present (${cached.toString()})');
      }
    } catch (_) {}

    // If token is not a standard Facebook access token, prefer backend verification
    // First, try server-side exchange: POST the raw access token to backend /auth/facebook.
    // Backend will validate the token with Facebook Graph API and create/upsert the user.
    try {
      final body = {'accessToken': tokenValue};
      if (looksLikeJwt) body['tokenType'] = 'id_token';
      final serverResp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      if (kDebugMode) print('facebookAuth: backend /auth/facebook returned status=${serverResp.statusCode}');
      if (serverResp.statusCode >= 200 && serverResp.statusCode < 300) {
        // Backend accepted token and returned user/session info — return immediately.
        return jsonDecode(serverResp.body) as Map<String, dynamic>;
      }
      // If backend returned 4xx, fall through to attempt client-side Firebase sign-in as fallback.
      if (kDebugMode) {
        print('facebookAuth: backend rejected token, body=${serverResp.body} — falling back to client-side flow');
      }
    } catch (backendErr) {
      if (kDebugMode) print('facebookAuth: backend /auth/facebook call failed: $backendErr');
      // continue to client-side sign-in fallback
    }

    // If token doesn't look like standard EAA token, and server didn't accept it, inform caller early
    if (!looksLikeEAA && !looksLikeJwt) {
      return {'error': true, 'message': 'Facebook access token format not recognized by client; backend verification failed'};
    }

    // Ensure Firebase initialized
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {}

    // Sign in to Firebase with Facebook credential
    try {
      final credential = FacebookAuthProvider.credential(tokenValue);
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);

      // Attempt guarded write of minimal profile
      try {
        final uid = userCred.user?.uid;
        final displayName = userCred.user?.displayName;
        final email = userCred.user?.email;
        if (uid != null) {
          final db = FirebaseFirestore.instance;
          final doc = db.collection('users').doc(uid);
          final minimal = <String, dynamic>{
            if (displayName != null) 'displayName': displayName,
            if (email != null) 'email': email,
            'lastSeen': DateTime.now().toIso8601String(),
          };
          try {
            await doc.set(minimal, SetOptions(merge: true));
            if (kDebugMode) print('FacebookAuthService: wrote minimal profile for $uid');
          } catch (e) {
            if (e is FirebaseException && e.code == 'permission-denied') {
              if (kDebugMode) print('FacebookAuthService: permission-denied writing profile; enqueueing');
              try {
                await ProfileSyncService.instance.saveProfilePartial(minimal);
              } catch (_) {}
            } else {
              if (kDebugMode) print('FacebookAuthService: unexpected error writing profile: $e');
            }
          }
        }
      } catch (_) {}

      // Exchange Firebase ID token with backend
      final firebaseIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (firebaseIdToken == null) return {'error': true, 'message': 'Failed to get Firebase ID token'};
      final resp = await http.post(Uri.parse('$backendBaseUrl/auth/login'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'idToken': firebaseIdToken}));
      if (resp.statusCode >= 200 && resp.statusCode < 300) return jsonDecode(resp.body) as Map<String, dynamic>;

      // fallback: return local user info
      return {
        'token': null,
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'email': FirebaseAuth.instance.currentUser?.email,
      };
    } on FirebaseAuthException catch (e) {
      final code = e.code;
      String userMessage = 'Facebook sign-in failed';
      if (code == 'invalid-credential') userMessage = 'Invalid Facebook credentials. Please try again.';
      if (code == 'account-exists-with-different-credential') userMessage = 'An account already exists with a different sign-in method.';
      return {'error': true, 'message': userMessage, 'code': code};
    } catch (e) {
      // As a final fallback, post token to backend dev endpoint
      final body = {'accessToken': tokenValue, 'tokenType': looksLikeJwt ? 'id_token' : 'access_token'};
      final resp = await http.post(uri, headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
      if (resp.statusCode >= 200 && resp.statusCode < 300) return jsonDecode(resp.body) as Map<String, dynamic>;
      return {'error': true, 'message': 'Facebook authentication failed', 'detail': resp.body};
    }
  }
}
