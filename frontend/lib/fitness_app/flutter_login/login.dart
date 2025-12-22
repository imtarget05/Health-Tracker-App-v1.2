// Suppress low-risk analyzer messages about private state types exposed
// via the public widget API. These widgets intentionally use private
// State classes per Flutter conventions.
// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import './register.dart';
import './resetpassword.dart';
import '../welcome/onboarding_screen.dart';
import '../input_information/welcome_screen.dart';
import '../fitness_app_home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase_options.dart';
import '../../services/backend_api.dart';
import '../../services/auth_storage.dart';
import '../../services/google_auth_service.dart';
import '../../services/facebook_auth_service.dart';
import '../../services/profile_sync_service.dart';
import 'package:best_flutter_ui_templates/services/event_bus.dart';

class LoginPage extends StatefulWidget {
  final String? title;

  const LoginPage({super.key, this.title});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _obscurePassword = true;

  bool _isLoading = false;
  bool _firebaseReady = false;
  // Firebase init error shown to user when initialization fails.
  // The field is intentionally kept for future UX messaging; suppress unused-field for now.
  // ignore: unused_field
  String? _firebaseInitError;

  @override
  void initState() {
    super.initState();
    _ensureFirebaseInitialized();
  }

  // Helper: detect noisy platform/network plugin messages and emit a friendly
  // user-facing message while keeping the raw text in debug logs for devs.
  bool _isNetworkError(String? message) {
    if (message == null) return false;
    final m = message.toLowerCase();
    return m.contains('network') || m.contains('timeout') || m.contains('interrupted') ||
        m.contains('unreachable') || m.contains('socketexception') || m.contains('failed host lookup') ||
        m.contains('host lookup') || m.contains('connection timed out');
  }

  void _emitFriendlyError(Object? raw, [String? fallback]) {
    final rawStr = raw?.toString();
    if (_isNetworkError(rawStr)) {
      debugPrint('Login: raw error (network-like): $rawStr');
  EventBus.instance.emitError('Temporary network error. Please check your connection and try again.');
      return;
    }
  final msg = fallback ?? rawStr ?? 'An error occurred. Please try again.';
    debugPrint('Login: error emitted (raw): $rawStr');
    EventBus.instance.emitError(msg);
  }

  Future<void> _routeAfterLogin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
  debugPrint('Login: _routeAfterLogin called, user=${user?.uid}');
      if (user == null) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OnboardingScreen()));
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.exists ? (doc.data() ?? <String, dynamic>{}) : <String, dynamic>{};
  debugPrint('Login: fetched user doc, keys=${data.keys.toList()}');

      // If a user document already exists with any data, treat the account as configured
      if (doc.exists && data.isNotEmpty) {
        debugPrint('Login: user doc exists and is non-empty - routing to home');
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
        return;
      }

      // reuse register.dart's heuristics to decide where to route
      bool needsInputInformation(Map<String, dynamic> d) {
        final p = (d['profile'] is Map<String, dynamic>) ? d['profile'] as Map<String, dynamic> : <String, dynamic>{};
        dynamic getField(String key) => p.containsKey(key) ? p[key] : d[key];
        final age = getField('age');
        final gender = getField('gender');
        final weightKg = getField('weightKg');
        final heightCm = getField('heightCm');
        final idealWeightKg = getField('idealWeightKg');
        final deadline = getField('deadline');
        if (age == null) return true;
        if (gender == null || gender.toString().trim().isEmpty) return true;
        if (weightKg == null) return true;
        if (heightCm == null) return true;
        if (idealWeightKg == null) return true;
        if (deadline == null || deadline.toString().trim().isEmpty) return true;
        return false;
      }

      bool needsOnboarding(Map<String, dynamic> d) {
        final p = (d['profile'] is Map<String, dynamic>) ? d['profile'] as Map<String, dynamic> : <String, dynamic>{};
        dynamic getField(String key) => p.containsKey(key) ? p[key] : d[key];
        final training = getField('trainingIntensity');
        final diet = getField('dietPlan');
        final onboardingName = getField('fullName') ?? getField('displayName') ?? getField('name');
        if (training == null || training.toString().trim().isEmpty) return true;
        if (diet == null || diet.toString().trim().isEmpty) return true;
        if (onboardingName == null || onboardingName.toString().trim().isEmpty) return true;
        return false;
      }

      // If onboarding fields are missing, route user into onboarding_contents first
      if (needsOnboarding(data)) {
        debugPrint('Login: routing -> OnboardingScreen (needsOnboarding)');
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        return;
      }

      // If habit data is present in the user doc, consider profile complete and go home
      if (data['habit'] != null) {
        debugPrint('Login: routing -> FitnessAppHomeScreen (habit present)');
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
        return;
      }

      // If input-information fields are missing, route to WelcomeScreen
      if (needsInputInformation(data)) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
        return;
      }

      // Otherwise the user has completed onboarding + input information — go to app home
  if (!mounted) return;
  debugPrint('Login: routing -> FitnessAppHomeScreen (default)');
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
    } catch (e) {
      // fallback to onboarding on error
      if (!mounted) return;
  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    }
  }

  Future<void> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      setState(() {
        _firebaseReady = true;
        _firebaseInitError = null;
      });
    } catch (e) {
      setState(() {
        _firebaseReady = false;
        _firebaseInitError = e.toString();
      });
    }
  }

  Widget get _logo => Center(
    child: Hero(
      tag: 'hero',
      child: CircleAvatar(
        backgroundColor: Colors.transparent,
        radius: 100,
        child: Image.asset('assets/images/doctor.png'),
      ),
    ),
  );

  Widget get _userNameField => TextFormField(
    controller: _emailCtrl,
    keyboardType: TextInputType.emailAddress,
    validator: (value) {
      final v = value?.trim() ?? '';
      if (v.isEmpty) return 'Please enter email';
      final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+");
      if (!emailRegex.hasMatch(v)) return 'Please enter a valid email';
      return null;
    },
    decoration: const InputDecoration(
      labelText: "EMAIL",
      labelStyle: TextStyle(fontWeight: FontWeight.bold),
    ),
  );

  Widget get _passwordField => TextFormField(
    controller: _passCtrl,
    obscureText: _obscurePassword,
    validator: (value) {
      if (value == null || value.isEmpty) {
        return "Please enter the password";
      } else if (value.length < 6) {
        return "Password must be at least 6 characters";
      }
      return null;
    },
    decoration: InputDecoration(
        labelText: "PASSWORD",
        labelStyle: TextStyle(fontWeight: FontWeight.bold),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
    ),
  );

  Widget get _forgotPassword => Container(
    alignment: Alignment.centerRight,
    child: InkWell(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ResetPasswordPage(title: 'Reset Password')));
      },
      child: const Text(
        "Forgot Password?",
        style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
            decoration: TextDecoration.underline),
      ),
    ),
  );

  Widget get _loginButton => SizedBox(
    width: double.infinity,
    height: 45,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20))),
    onPressed: (!_firebaseReady || _isLoading)
      ? null
      : () async {
        if (!_formKey.currentState!.validate()) return;

        setState(() => _isLoading = true);

        try {
          // Ensure Firebase initialized
          if (Firebase.apps.isEmpty) {
            try {
              await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
            } catch (initErr) {
              setState(() => _isLoading = false);
              _emitFriendlyError(initErr, 'Không thể khởi tạo Firebase. Vui lòng thử lại.');
              return;
            }
          }
          // Sign in with Firebase Auth
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
          debugPrint('Login: signInWithEmailAndPassword resolved - waiting for auth state');
          try {
            await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null).timeout(const Duration(seconds: 6));
            debugPrint('Login: authState confirmed user=${FirebaseAuth.instance.currentUser?.uid}');
            try { await ProfileSyncService.instance.retryQueue(); } catch (_) {}
          } catch (e) {
            debugPrint('Login: authState wait after email sign-in timed out or failed: $e');
          }

          // Get ID token
          String? idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
          if (idToken == null) throw Exception('Failed to get ID token');

          // Send to backend and capture returned backend JWT
          final backendResp = await BackendApi.loginWithIdToken(idToken: idToken);
          final backendToken = backendResp['token'] as String?;
          if (backendToken != null) {
            // store token for subsequent API calls
            // use in-memory storage for now; consider secure storage for production
            AuthStorage.saveToken(backendToken);
          }

          // Navigate to dashboard
          await _routeAfterLogin();
        } catch (e) {
          final msg = e is Exception ? e.toString() : 'Login failed';
          _emitFriendlyError(e, 'Đăng nhập thất bại. Vui lòng thử lại.');
        } finally {
          setState(() => _isLoading = false);
        }
      },
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
        "LOGIN",
        style: TextStyle(
            fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(widget.title ?? "Login")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _logo,
              const SizedBox(height: 30),
              _userNameField,
              const SizedBox(height: 20),
              _passwordField,
              const SizedBox(height: 20),
              _forgotPassword,
              const SizedBox(height: 20),
              _loginButton,
              const SizedBox(height: 16),
              // Social login buttons (responsive)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: (!_firebaseReady || _isLoading)
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            try {
                              final svc = GoogleAuthService();
                              final backendBase = Uri.base.host == '' ? 'http://127.0.0.1:5001' : 'http://127.0.0.1:5001';
                              final result = await svc.signInToBackend(backendBase);
                              if (result != null) {
                                // result now contains 'backend' and google tokens
                                final backend = result['backend'] as Map<String, dynamic>?;
                                final idToken = result['idToken'] as String?;
                                final accessToken = result['accessToken'] as String?;

                                // Sign-in the Firebase client SDK locally so ProfileSync can write
                                try {
                                  if (idToken != null) {
                                    // use Firebase Auth to sign in by credential
                                    // Note: ensure firebase_auth is imported in this file
                                    // to make this work. If not available, we fallback.
                                    try {
                                      final credential = GoogleAuthProvider.credential(
                                        idToken: idToken,
                                        accessToken: accessToken,
                                      );
                                      await FirebaseAuth.instance.signInWithCredential(credential);
                                      debugPrint('Login: signInWithCredential resolved (Google) - waiting for auth state');
                                      try {
                                        await FirebaseAuth.instance.authStateChanges().firstWhere((u) => u != null).timeout(const Duration(seconds: 6));
                    debugPrint('Login: authState confirmed user=${FirebaseAuth.instance.currentUser?.uid} (Google)');
                      EventBus.instance.emitInfo('Firebase client signed in (Google)');
                      try { await ProfileSyncService.instance.retryQueue(); } catch (_) {}
                                      } catch (e) {
                                        debugPrint('Login: authState wait after Google credential sign-in timed out or failed: $e');
                                      }
                                    } catch (_) {
                                      // ignore; fallback relies on backend token
                                    }
                                  }
                                } catch (_) {}

                                final token = backend != null ? backend['token'] as String? : null;
                                final existingAccount = backend != null ? (backend['existingAccount'] == true) : false;
                                // backend may set _firebaseSignedIn when it created a custom token or
                                // when we performed credential sign-in earlier; we don't rely on
                                // this variable for the immediate existingAccount routing.
                                if (token != null) {
                                  AuthStorage.saveToken(token);
                                }

                                // If backend told us this is an existing account and the Firebase client is signed in,
                                // route directly to the app home. Otherwise perform the normal route checks.
                                // If backend told us this is an existing account and the Firebase client is signed in,
                                // route directly to the app home. Also allow routing if the local FirebaseAuth.currentUser
                                // is non-null even if the backend response didn't set _firebaseSignedIn (safety net).
                                // If backend told us this is an existing account, route directly to the app home
                                // immediately (user already has a configured profile). This makes the UX faster
                                // and avoids blocking navigation on slight client-side auth timing races.
                                if (existingAccount) {
                                  debugPrint('Login: backend existingAccount -> routing to home immediately');
                                  EventBus.instance.emitInfo('login success');
                                  // Trigger profile sync in background and don't await to avoid
                                  // holding the BuildContext across async gaps.
                                  try { ProfileSyncService.instance.retryQueue(); } catch (_) {}
                                  if (!mounted) return;
                                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
                                  return;
                                }

                                // Trigger an immediate retry of the profile sync queue (best-effort)
                                try { ProfileSyncService.instance.retryQueue(); } catch (_) {}
                                await _routeAfterLogin();
                              }
                            } catch (e, st) {
                              EventBus.instance.emitError('Đăng nhập bằng Google thất bại. Vui lòng thử lại.');
                              if (kDebugMode) debugPrint('Login: Google sign-in failed: $e\n$st');
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          },
                    icon: Image.asset('assets/images/google_logo.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.g_mobiledata)),
                    label: const Text('Google'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      minimumSize: const Size(140, 44),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: (!_firebaseReady || _isLoading)
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            try {
                              final svc = FacebookAuthService();
                              final backendBase = Uri.base.host == '' ? 'http://127.0.0.1:5001' : 'http://127.0.0.1:5001';
                              final result = await svc.signInToBackend(backendBase);
                              if (result != null) {
                                final token = result['token'] as String?;
                                if (token != null) {
                                  AuthStorage.saveToken(token);
                                }
                                await _routeAfterLogin();
                              }
                            } catch (e, st) {
                              EventBus.instance.emitError('Đăng nhập bằng Facebook thất bại. Vui lòng thử lại.');
                              if (kDebugMode) debugPrint('Login: Facebook sign-in failed: $e\n$st');
                            } finally {
                              setState(() => _isLoading = false);
                            }
                          },
                    icon: Image.asset('assets/images/facebook_logo.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.facebook)),
                    label: const Text('Facebook'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      minimumSize: const Size(140, 44),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("New to Account? "),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RegisterPage(title: 'Register')));
                    },
                    child: const Text(
                      "Create a new account",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}