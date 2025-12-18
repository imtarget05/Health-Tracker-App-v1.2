import 'package:flutter/material.dart';
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

  const LoginPage({Key? key, this.title}) : super(key: key);

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
  String? _firebaseInitError;

  @override
  void initState() {
    super.initState();
    _ensureFirebaseInitialized();
  }

  Future<void> _routeAfterLogin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OnboardingScreen()));
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.exists ? (doc.data() ?? <String, dynamic>{}) : <String, dynamic>{};

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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        return;
      }

      // If input-information fields are missing, route to WelcomeScreen
      if (needsInputInformation(data)) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
        return;
      }

      // Otherwise the user has completed onboarding + input information — go to app home
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
    } catch (e) {
      // fallback to onboarding on error
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OnboardingScreen()));
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
              EventBus.instance.emitError('Firebase init failed: $initErr');
              return;
            }
          }
          // Sign in with Firebase Auth
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );

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
          EventBus.instance.emitError(msg);
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
                                    } catch (_) {
                                      // ignore; fallback relies on backend token
                                    }
                                  }
                                } catch (_) {}

                                final token = backend != null ? backend['token'] as String? : null;
                                if (token != null) {
                                  AuthStorage.saveToken(token);
                                }

                                // Trigger an immediate retry of the profile sync queue.
                                try {
                                  ProfileSyncService.instance.retryQueue();
                                } catch (_) {}
                                  await _routeAfterLogin();
                              }
                            } catch (e) {
                              EventBus.instance.emitError('Google sign-in failed: $e');
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
                            } catch (e) {
                              EventBus.instance.emitError('Facebook sign-in failed: $e');
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