import 'package:flutter/material.dart';
import './register.dart';
import './resetpassword.dart';

import '../welcome/onboarding_screen.dart';
// '../my_diary/my_diary_screen.dart' is not used in this file
import '../fitness_app_home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import '../../services/backend_api.dart';
import '../../services/auth_storage.dart';
import '../../services/google_auth_service.dart';
import '../../services/facebook_auth_service.dart';
import '../profile/edit_profile.dart';
import '../input_information/welcome_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // _firebaseInitError removed because it was never used by the UI

  @override
  void initState() {
    super.initState();
    _ensureFirebaseInitialized();
  }

  Future<void> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      setState(() {
        _firebaseReady = true;
      });
    } catch (e) {
      setState(() {
        _firebaseReady = false;
  // intentionally not storing the error string on the state since
  // it wasn't being displayed anywhere in the UI
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

        // capture navigator and messenger before any awaits to avoid using a
        // BuildContext across async gaps
        final scaffold = ScaffoldMessenger.of(context);
        final nav = Navigator.of(context);

        setState(() => _isLoading = true);

        try {
          // Ensure Firebase initialized
          if (Firebase.apps.isEmpty) {
            try {
              await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
            } catch (initErr) {
              if (mounted) setState(() => _isLoading = false);
              scaffold.showSnackBar(
                SnackBar(content: Text('Firebase init failed: $initErr')),
              );
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

          // Ensure profile completeness then navigate using captured navigator
          await _ensureProfileCompletedAndNavigate(nav);
        } catch (e) {
          final msg = e is Exception ? e.toString() : 'Login failed';
          if (mounted) {
            scaffold.showSnackBar(
              SnackBar(content: Text(msg)),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
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
                            // capture context-bound objects before async work
                            final scaffold = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(context);
                            setState(() => _isLoading = true);
                            try {
                              final svc = GoogleAuthService();
                              final backendBase = BackendApi.baseUrl;
                              final result = await svc.signInToBackend(backendBase);
                                if (result == null) {
                                  // user cancelled the Google sign-in flow
                                  scaffold.showSnackBar(const SnackBar(content: Text('Google sign-in cancelled')));
                                } else if (result is Map && result['error'] == true) {
                                  final msg = result['message'] ?? 'Google sign-in failed';
                                  scaffold.showSnackBar(SnackBar(content: Text(msg)));
                                } else {
                                  final token = result['token'] as String?;
                                  if (token != null) AuthStorage.saveToken(token);
                                  // If backend returned a user object with a fullName or profile,
                                  // assume backend has the authoritative profile state and navigate
                                  // directly into the app to avoid extra client-side Firestore reads/writes.
                                  bool backendHasName = false;
                                  try {
                                    if (result['fullName'] != null && result['fullName'].toString().trim().isNotEmpty) backendHasName = true;
                                    final profileMap = result['profile'];
                                    if (!backendHasName && profileMap is Map) {
                                      if ((profileMap['fullName'] != null && profileMap['fullName'].toString().trim().isNotEmpty)) backendHasName = true;
                                    }
                                  } catch (_) {}

                                  if (backendHasName) {
                                    // navigate directly into home
                                    nav.pushReplacement(MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
                                  } else {
                                    await _ensureProfileCompletedAndNavigate(nav);
                                  }
                                }
                            } catch (e) {
                              scaffold.showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
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
                            final scaffold = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(context);
                            setState(() => _isLoading = true);
                            try {
                              final svc = FacebookAuthService();
                              final backendBase = BackendApi.baseUrl;
                              final result = await svc.signInToBackend(backendBase);
                                if (result == null) {
                                  scaffold.showSnackBar(const SnackBar(content: Text('Facebook sign-in cancelled')));
                                } else if (result is Map && result['error'] == true) {
                                  final msg = result['message'] ?? 'Facebook sign-in failed';
                                  scaffold.showSnackBar(SnackBar(content: Text(msg)));
                                } else {
                                  final token = result['token'] as String?;
                                  if (token != null) AuthStorage.saveToken(token);
                                    // Backend authoritative check: if backend returned a name/profile,
                                    // skip client-side profile checks and go straight to app.
                                    bool backendHasName = false;
                                    try {
                                      if (result['fullName'] != null && result['fullName'].toString().trim().isNotEmpty) backendHasName = true;
                                      final profileMap = result['profile'];
                                      if (!backendHasName && profileMap is Map) {
                                        if ((profileMap['fullName'] != null && profileMap['fullName'].toString().trim().isNotEmpty)) backendHasName = true;
                                      }
                                    } catch (_) {}

                                    if (backendHasName) {
                                      nav.pushReplacement(MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
                                    } else {
                                      await _ensureProfileCompletedAndNavigate(nav);
                                    }
                                }
                            } catch (e) {
                              scaffold.showSnackBar(SnackBar(content: Text('Facebook sign-in failed: $e')));
                            } finally {
                              if (mounted) setState(() => _isLoading = false);
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

// Helper placed after the LoginPage class to reuse imports
Future<void> _ensureProfileCompletedAndNavigate(NavigatorState nav) async {
  // This can only be called when FirebaseAuth.currentUser is non-null
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  Map<String, dynamic> data = {};
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    data = doc.data() ?? {};
  } catch (e) {
    // If Firestore rules block reads (permission-denied) or network fails,
    // proceed into app — backend should own profile reconciliation.
    // Avoid surfacing the raw firestore error to the user here.
    data = {};
  }

  // Check multiple locations for a name/email to consider profile complete
  String? resolveName(Map<String, dynamic> d) {
    final candidates = [
      d['fullName'],
      d['displayName'],
      d['name'],
    ];
    for (final c in candidates) {
      if (c != null && c.toString().trim().isNotEmpty) return c.toString().trim();
    }
    // nested profile map
    final p = d['profile'];
    if (p is Map<String, dynamic>) {
      final pc = [p['fullName'], p['displayName'], p['name']];
      for (final c in pc) {
        if (c != null && c.toString().trim().isNotEmpty) return c.toString().trim();
      }
    }
    return null;
  }

  bool needsInputInformation(Map<String, dynamic> d) {
    // The input_information flow stores fields under the 'profile' map.
    final p = (d['profile'] is Map<String, dynamic>) ? d['profile'] as Map<String, dynamic> : <String, dynamic>{};
    // Accept values either at top-level or under profile
    dynamic getField(String key) => p.containsKey(key) ? p[key] : d[key];

    final age = getField('age');
    final gender = getField('gender');
    final weightKg = getField('weightKg');
    final heightCm = getField('heightCm');
    final idealWeightKg = getField('idealWeightKg');
    final deadline = getField('deadline');

    // If any required onboarding field is missing or empty, we need the input flow.
    if (age == null) return true;
    if (gender == null || gender.toString().trim().isEmpty) return true;
    if (weightKg == null) return true;
    if (heightCm == null) return true;
    if (idealWeightKg == null) return true;
    if (deadline == null || deadline.toString().trim().isEmpty) return true;
    return false;
  }

  bool needsOnboarding(Map<String, dynamic> d) {
    // Onboarding expects trainingIntensity, dietPlan and a fullName under profile
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

  final hasName = resolveName(data) != null;

  // If onboarding is missing, route user through onboarding contents first
  if (needsOnboarding(data)) {
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    return;
  }

  // If input-information is missing, route the user into that flow
  if (needsInputInformation(data)) {
    // Replace the login route with the onboarding input flow
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
    return;
  }

  // If profile is missing a display name, open EditProfilePage; if user cancels, remain on Login screen
  if (!hasName) {
    final saved = await nav.push<bool>(MaterialPageRoute(builder: (_) => const EditProfilePage()));
    if (saved == true) {
      // reload doc and continue
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      // navigate into the 5-tab home
      nav.pushReplacement(MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
    } else {
      // user cancelled: do not auto-navigate into app
      return;
    }
    return;
  }

  // profile exists and no onboarding required: go straight into the 5-tab home
  nav.pushReplacement(MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
}