import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import 'profile_sync_service.dart';
// keep available for init ordering

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
    // On web, the plugin reads the client id from the meta tag. Passing the
    // clientId explicitly here ensures sign-in works when building for web.
    clientId: kIsWeb ? '484752358530-rcv2nggm1ari9rhmojl2v27i1fv0eguh.apps.googleusercontent.com' : null,
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
      if (accessToken == null) {
        return {'error': true, 'message': 'Không thể lấy token Google. Vui lòng thử lại.'};
      }
    }
    // Ensure Firebase client initialized (Register/Login pages already init but be defensive)
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (_) {}

    // Sign in to Firebase using Google credentials to ensure a Firebase user exists
    if (googleAuth.accessToken == null) {
      // accessToken may be null on some platforms; still attempt sign-in using idToken
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken, accessToken: googleAuth.accessToken);
    UserCredential? userCred;
    try {
      // Sign in to Firebase with Google credential
      userCred = await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      // Map common error codes to friendly messages for the UI
      final code = e.code;
      String userMessage = 'Google sign-in failed';
      if (code == 'invalid-credential' || code == 'invalid-provider-id') {
        userMessage = 'Thông tin đăng nhập Google không hợp lệ hoặc đã hết hạn. Vui lòng thử lại.';
      } else if (code == 'user-disabled') {
        userMessage = 'Your account has been disabled.';
      } else if (code == 'account-exists-with-different-credential') {
        userMessage = 'An account already exists with a different sign-in method.';
      } else if (code == 'operation-not-allowed') {
        userMessage = 'Google sign-in is not enabled for this project.';
      }
      // Return a structured error object for the caller to surface
      return {'error': true, 'message': userMessage, 'code': code};
    } catch (e) {
      return {'error': true, 'message': 'Unexpected error during Google sign-in', 'code': 'unknown'};
    }

      // After successful Firebase sign-in, get Firebase ID token and call backend immediately.
      final firebaseIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (firebaseIdToken == null) return {'error': true, 'message': 'Failed to get Firebase id token after sign-in'};

      try {
        final resp = await http.post(
          Uri.parse('$backendBaseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': firebaseIdToken}),
        );

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          // Backend accepted token and returned user profile/session. Assume backend
          // knows whether profile is complete — return this to the caller and avoid
          // any client-side Firestore write or debug prints.
          return jsonDecode(resp.body) as Map<String, dynamic>;
        }
        // If backend returned non-2xx, fall through to attempt client write as fallback
      } catch (backendErr) {
        // network or server error — fall back to attempting local write/queue
        if (kDebugMode) print('GoogleAuthService: backend /auth/login failed: $backendErr');
      }

      // Fallback: try guarded write of minimal profile on client only if backend didn't accept
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
            if (kDebugMode) print('GoogleAuthService: wrote minimal profile for $uid');
          } catch (e) {
            if (e is FirebaseException && e.code == 'permission-denied') {
              // enqueue for later without noisy prints in production
              if (kDebugMode) print('GoogleAuthService: permission-denied writing profile; enqueueing');
              try {
                await ProfileSyncService.instance.saveProfilePartial(minimal);
              } catch (_) {}
            } else {
              if (kDebugMode) print('GoogleAuthService: unexpected error writing profile: $e');
            }
          }
        }
      } catch (_) {}

      // As a last resort, return local user info to let app continue
      try {
        final local = {
          'token': null,
          'uid': FirebaseAuth.instance.currentUser?.uid,
          'email': FirebaseAuth.instance.currentUser?.email,
          'fullName': FirebaseAuth.instance.currentUser?.displayName,
        };
        return local;
      } catch (_) {
        return {'error': true, 'message': 'Failed to complete Google sign-in flow'};
      }
  }

  /// Optional: sign out from Google on device
  Future<void> signOut() => _googleSignIn.signOut();
}
