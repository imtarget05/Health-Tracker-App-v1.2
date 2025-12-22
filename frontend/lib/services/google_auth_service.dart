import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:best_flutter_ui_templates/services/event_bus.dart';
import 'package:best_flutter_ui_templates/services/profile_sync_service.dart';

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
    // If backend returned a firebase custom token, use it to sign in the
    // Firebase client SDK so currentUser is set. If no custom token was
    // provided but the backend indicates an existing account, attempt to
    // sign in the Firebase client SDK directly with the Google credential
    // (this helps the local client set FirebaseAuth.currentUser so
    // ProfileSync can flush queued items).
    final firebaseCustomToken = backend['firebaseCustomToken'] as String?;
    final backendHasExistingAccount = backend['existingAccount'] == true || backend['existing_account'] == true;
  if (firebaseCustomToken != null && firebaseCustomToken.isNotEmpty) {
        // helper: retry signInWithCustomToken with small backoff
        Future<bool> trySignInWithCustomToken(String token) async {
          int attempts = 0;
          while (attempts < 3) {
            attempts += 1;
            try {
              await FirebaseAuth.instance.signInWithCustomToken(token);
              debugPrint('GoogleAuthService: trySignInWithCustomToken attempt $attempts resolved');
              try {
                await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null).timeout(const Duration(seconds: 6));
                debugPrint('GoogleAuthService: authState confirmed user=${FirebaseAuth.instance.currentUser?.uid}');
                return true;
              } catch (e) {
                debugPrint('GoogleAuthService: authState wait failed on attempt $attempts: $e');
              }
            } catch (e) {
              debugPrint('GoogleAuthService: signInWithCustomToken failed on attempt $attempts: $e');
            }
            await Future.delayed(Duration(milliseconds: 300 * attempts));
          }
          return false;
        }

        try {
          final ok = await trySignInWithCustomToken(firebaseCustomToken);
          if (ok) {
            debugPrint('GoogleAuthService: signed in via custom token, uid=${FirebaseAuth.instance.currentUser?.uid}');
            EventBus.instance.emitInfo('Firebase client signed in (custom token)');
            try { await ProfileSyncService.instance.retryQueue(); } catch (e) { debugPrint('GoogleAuthService: retryQueue error: $e'); }
          }
          backend['_firebaseSignedIn'] = ok;
        } catch (_) {}
      }
      else if (backendHasExistingAccount) {
        // Fallback: use Google credential to sign in the Firebase client SDK
        // so that FirebaseAuth.instance.currentUser is populated. Wait for
        // authStateChanges to confirm the local client is signed in before
        // attempting ProfileSync retry to avoid races where currentUser is
        // still null.
        try {
          final credential = GoogleAuthProvider.credential(idToken: idToken, accessToken: accessToken);
          final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
          debugPrint('GoogleAuthService: signInWithCredential returned uid=${userCred.user?.uid}');
          // Wait for authState to settle and confirm a non-null user.
          try {
            await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null).timeout(const Duration(seconds: 6));
            debugPrint('GoogleAuthService: authState confirmed user=${FirebaseAuth.instance.currentUser?.uid} after credential sign-in');
            EventBus.instance.emitInfo('Firebase client signed in (Google credential)');
            try { await ProfileSyncService.instance.retryQueue(); } catch (e) { debugPrint('GoogleAuthService: retryQueue error after credential: $e'); }
            backend['_firebaseSignedIn'] = FirebaseAuth.instance.currentUser != null;
          } catch (e) {
            debugPrint('GoogleAuthService: authState did not confirm after credential sign-in: $e');
            backend['_firebaseSignedIn'] = false;
          }
        } catch (e) {
          debugPrint('GoogleAuthService: signInWithCredential failed: $e');
          backend['_firebaseSignedIn'] = false;
        }
      }
      // Emit a global success event; UI will show a toast.
      EventBus.instance.emitSuccess('Đăng nhập thành công.');
      // Return backend response and tokens. backend may include existingAccount and _firebaseSignedIn
      return {
        'backend': backend,
        'idToken': idToken,
        'accessToken': accessToken,
      };
    }

    EventBus.instance.emitError('Đăng nhập thất bại.');
    throw Exception('Backend Google auth failed: ${resp.statusCode} ${resp.body}');
  }

  /// Optional: sign out from Google on device
  Future<void> signOut() => _googleSignIn.signOut();
}
