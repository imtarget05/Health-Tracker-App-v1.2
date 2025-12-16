import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
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
    if (idToken == null) {
      throw Exception('Failed to obtain Google idToken');
    }
    // Ensure Firebase client initialized (Register/Login pages already init but be defensive)
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
    } catch (_) {}

    // Sign in to Firebase using Google credentials to ensure a Firebase user exists
    final credential = GoogleAuthProvider.credential(idToken: idToken, accessToken: googleAuth.accessToken);
    final userCred = await FirebaseAuth.instance.signInWithCredential(credential);

    // Ensure Firestore profile exists (client-side) so app has immediate profile
    try {
      final db = FirebaseFirestore.instance;
      final uid = userCred.user?.uid;
      if (uid != null) {
        final userDoc = db.collection('users').doc(uid);
        final snap = await userDoc.get();
        if (!snap.exists) {
          final profile = {
            'uid': uid,
            'email': userCred.user?.email ?? account.email,
            'fullName': userCred.user?.displayName ?? account.displayName ?? '',
            'profilePic': userCred.user?.photoURL ?? account.photoUrl ?? '',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
            'provider': 'google',
            'providerId': userCred.user?.uid,
          };
          await userDoc.set(profile);
        }
      }
    } catch (e) {
      // non-fatal: log and continue to backend login step
      // ignore: avoid_print
      print('GoogleAuthService: failed to create client-side Firestore profile: $e');
    }

    // Get Firebase ID token and send to backend login endpoint to get backend JWT
    final firebaseIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (firebaseIdToken == null) throw Exception('Failed to get Firebase idToken after sign-in');

    final resp = await http.post(
      Uri.parse('$backendBaseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': firebaseIdToken}),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }

    // If backend login fails, still return local user info to let app continue
    try {
      final local = {
        'token': null,
        'uid': FirebaseAuth.instance.currentUser?.uid,
        'email': FirebaseAuth.instance.currentUser?.email,
        'fullName': FirebaseAuth.instance.currentUser?.displayName,
      };
      return local;
    } catch (_) {
      throw Exception('Backend Google auth failed: ${resp.statusCode} ${resp.body}');
    }
  }

  /// Optional: sign out from Google on device
  Future<void> signOut() => _googleSignIn.signOut();
}
