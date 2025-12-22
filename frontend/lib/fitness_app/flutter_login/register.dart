import 'package:flutter/material.dart';
import './login.dart';
// ...existing imports...
import '../../services/pending_signup.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import '../../services/backend_api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/profile_sync_service.dart';
import '../profile/edit_profile.dart';
import '../input_information/welcome_screen.dart';
import '../welcome/onboarding_screen.dart';
import '../fitness_app_home_screen.dart';
import 'package:best_flutter_ui_templates/services/event_bus.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.title});
  final String title;
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _firebaseReady = false;
  String? _firebaseInitError;

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
        _firebaseInitError = null;
      });
    } catch (e) {
      setState(() {
        _firebaseReady = false;
        _firebaseInitError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Heuristic to detect noisy platform/network error strings so the UI
  // doesn't surface them as raw toasts. Return true if message looks like
  // a transient network/platform error that we should suppress.
  // NOTE: _isNetworkError removed to make registration errors easier to debug.
  // Previously we converted noisy platform network errors into a friendly message.
  // This made it hard to see the original error during troubleshooting, so we
  // now emit the computed error message directly from registration code.

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      _performSignup();
    }
  }

  Future<void> _performSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();

  // capture context-bound objects before async gaps
  final nav = Navigator.of(context);
  final rootNav = Navigator.of(context, rootNavigator: true);

    setState(() {});

    bool _dialogClosed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Ensure Firebase is initialized before attempting Auth
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }
      } catch (initErr) {
        try { if (mounted) nav.pop(); } catch (_) {}
        debugPrint('Register: Firebase init failed: $initErr');
        EventBus.instance.emitError('Unable to initialize Firebase. Please try again.');
        return;
      }

      // Save pending signup info and attempt backend registration immediately.
      PendingSignup.set(email: email, password: password, fullName: email.split('@').first, phone: phone.isNotEmpty ? phone : null);
      try {
        final peek = PendingSignup.peek();
        if (peek != null) {
          final resp = await BackendApi.signup(
            fullName: peek['fullName'] ?? '',
            email: peek['email'] ?? '',
            password: peek['password'] ?? '',
            phone: peek['phone'],
          );
          // If backend returned a Firebase custom token, sign the client in so
          // the Firebase client SDK has a proper authenticated user and ID token.
          final custom = resp != null && resp['firebaseCustomToken'] != null ? resp['firebaseCustomToken'] as String? : null;
          if (custom != null) {
            try {
              await FirebaseAuth.instance.signInWithCustomToken(custom);
              // consume only if backend signup and client sign-in succeeded
              PendingSignup.consume();
            } catch (e) {
              debugPrint('Register: signInWithCustomToken failed: $e');
              // keep PendingSignup for later retry
            }
          } else {
            // No custom token; consume pending since backend signup succeeded.
            PendingSignup.consume();
          }
        }
      } catch (e, st) {
        debugPrint('Register: immediate backend signup failed, will keep PendingSignup for retry: $e\n$st');
      }

  // Try to create a Firebase user. If the email already exists, fall back to sign-in.
      // Track whether this call created a new user so we can route newly-registered users
      // into the input-information flow (WelcomeScreen) unconditionally.
  bool createdNewUser = false;
  String? createdUid;
      try {
        // If the client is already signed in (for example we signed in with a
        // backend-provided custom token above), skip createUser and treat the
        // existing session as the created user.
        final existing = FirebaseAuth.instance.currentUser;
        if (existing != null) {
          createdNewUser = true;
          createdUid = existing.uid;
        } else {
          final uc = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
          createdNewUser = true;
          createdUid = uc.user?.uid;
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use' || e.code == 'email-already-exists') {
          // existing account, attempt sign-in
          final signin = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
          createdUid = signin.user?.uid;
        } else {
          // If this looks like a transient network/plugin error, don't block the user.
          // We already saved PendingSignup above; allow the user to continue through
          // the onboarding/input flow and let background sync handle account creation
          // when network is available.
          final raw = e.message ?? e.toString();
          final detected = _isNetworkError(raw);
          if (detected) {
            debugPrint('Register: createUser network-like error; proceeding with pending signup: $raw');
            // We couldn't create the Firebase user due to transient network issues.
            // Keep pending signup saved but don't mark createdNewUser (no uid available).
            // pendingOnly was removed; keep behavior by falling through with PendingSignup saved.
          } else {
            // rethrow to be handled by outer catch
            rethrow;
          }
        }
      }


  // After sign-in, ensure the user completes profile once if missing
  // nav.pop() must be done in finally below to ensure the dialog is closed

      final user = FirebaseAuth.instance.currentUser;
      // If we created a new user (including the transient network-pending case),
      // prefer routing to the Welcome/input-information flow so the user can
      // complete their profile. We saved PendingSignup above so sync can finish later.
      if (createdNewUser) {
        // Close the loading dialog (if still open) before navigating so the
        // navigation stack remains consistent.
        try {
          if (!_dialogClosed) {
            if (mounted) nav.pop();
            _dialogClosed = true;
          }
        } catch (_) {}

        // Persist a minimal user document so onboarding / welcome screens
        // have a predictable shape to render. Use any PendingSignup info
        // (fullName/email) we captured earlier.
        try {
          final pending = PendingSignup.peek();
          final uidToWrite = createdUid ?? FirebaseAuth.instance.currentUser?.uid;
            if (uidToWrite != null) {
            final docRef = FirebaseFirestore.instance.collection('users').doc(uidToWrite);
            final minimal = <String, dynamic>{
              'uid': uidToWrite,
              'email': (FirebaseAuth.instance.currentUser?.email) ?? pending?['email'],
              'createdAt': DateTime.now().toIso8601String(),
              'profile': {
                'fullName': pending != null ? (pending['fullName'] ?? '') : (FirebaseAuth.instance.currentUser?.email?.split('@').first ?? ''),
                // other profile fields left absent so UI will treat them as missing
              }
            };
            await docRef.set(minimal, SetOptions(merge: true));
              // Minimal user doc written — do not call backend here because
              // we already attempted immediate backend signup earlier. The
              // PendingSignup will be consumed if the earlier call succeeded.
          } else {
            debugPrint('Register: no uid available to write minimal user doc');
          }
        } catch (e, st) {
          if (mounted) debugPrint('Register: failed to write minimal user doc: $e\n$st');
        }

        if (mounted) {
          // Emit diagnostic info: current auth uid and profile sync queue length
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final queueLen = ProfileSyncService.instance.readQueue().length;
          debugPrint('Register: navigating to OnboardingScreen (createdNewUser) uid=$currentUid queue=$queueLen');
          EventBus.instance.emitInfo('Debug: uid=${currentUid ?? '<null>'} queued=${queueLen}');
          EventBus.instance.emitSuccess('Registration successful.');
          rootNav.pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        }
        return;
      }

      if (user == null) {
        try { if (!_dialogClosed) { if (mounted) nav.pop(); _dialogClosed = true; } } catch (_) {}
        if (mounted) {
          final currentUid = FirebaseAuth.instance.currentUser?.uid;
          final queueLen = ProfileSyncService.instance.readQueue().length;
          debugPrint('Register: navigating to OnboardingScreen (no user) uid=$currentUid queue=$queueLen');
          EventBus.instance.emitInfo('Debug: uid=${currentUid ?? '<null>'} queued=${queueLen}');
          EventBus.instance.emitSuccess('Registration successful.');
          rootNav.pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        }
        return;
      }

      // Check firestore for existing profile info. If reads are blocked by
      // security rules (permission-denied) or network errors occur, assume
      // backend will handle profile creation and proceed into the app.
      Map<String, dynamic> data = {};
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        data = doc.data() ?? {};
      } catch (e) {
        // ignore firestore read errors and continue
        data = {};
      }

      String? resolveName(Map<String, dynamic> d) {
        final candidates = [d['fullName'], d['displayName'], d['name']];
        for (final c in candidates) {
          if (c != null && c.toString().trim().isNotEmpty) return c.toString().trim();
        }
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

      // If the user was just created, always route them into the input-information
      // flow first so they can complete the required fields. For existing accounts
      // we keep the previous heuristics (onboarding -> input information -> home).
      if (createdNewUser) {
        if (mounted) {
            nav.pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        }
        return;
      }

      // If onboarding fields are missing, route user into onboarding_contents first
      if (needsOnboarding(data)) {
        if (mounted) nav.pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
        return;
      }

      // If input-information fields are missing, route to WelcomeScreen
      if (needsInputInformation(data)) {
        if (mounted) nav.pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
        return;
      }

      if (resolveName(data) == null) {
        // Force the user to complete profile. If they cancel, ask to retry or logout.
        bool completed = false;
        while (!completed) {
          if (!mounted) return;
            final saved = await nav.push<bool>(MaterialPageRoute(builder: (_) => const EditProfilePage()));
          if (saved == true) {
            completed = true;
            break;
          }
          if (!mounted) return;
          final choice = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Profile Completion Required'),
              content: const Text('Please complete your profile to continue. Would you like to retry or sign out?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Retry')),
                TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Sign out')),
              ],
            ),
          );
          if (choice == false) {
            await FirebaseAuth.instance.signOut();
            return;
          }
        }
      }

      if (mounted) EventBus.instance.emitSuccess('Registration successful.');
      if (mounted) nav.pushReplacement(MaterialPageRoute(builder: (_) => const FitnessAppHomeScreen()));
  } on FirebaseAuthException catch (e) {
      // Handled below after finally
      String errorMsg = 'Registration failed';
      if (e.code == 'email-already-in-use' || e.code == 'email-already-exists') {
        errorMsg = 'Email already in use.';
      } else if (e.code == 'weak-password') {
        errorMsg = 'Password is too weak (minimum 6 characters).';
      } else if (e.code == 'invalid-email') {
        errorMsg = 'Invalid email address.';
      } else {
        final raw = e.message ?? e.toString();
        final detected = _isNetworkError(raw);
        if (mounted) debugPrint('Register: raw FirebaseAuthException message="$raw" detectedNetwork=$detected');
        if (detected) {
          errorMsg = 'Temporary network error. Please check your connection and try again.';
          if (mounted) debugPrint('Register: raw FirebaseAuthException (network-like): $raw');
        } else {
          errorMsg = raw;
        }
      }
  // Emit the computed error message (or a friendly network message) and
  // keep raw details in debug logs for developers.
  _emitFriendlyError(e, errorMsg);
  if (mounted) debugPrint('Register: error emitted: $errorMsg');
    } catch (e) {
  String errorMsg = 'Registration failed';
      if (e.toString().contains('email-already-exists') || e.toString().contains('email-already-in-use')) {
        errorMsg = 'Email already in use.';
      } else if (e.toString().contains('weak-password')) {
        errorMsg = 'Password is too weak (minimum 6 characters).';
      } else if (e.toString().contains('invalid-email')) {
        errorMsg = 'Invalid email address.';
      } else {
        // keep the raw message in logs for debugging but avoid showing raw
        // network/plugin messages directly to users which are noisy.
        final raw = e.toString();
        final detected = _isNetworkError(raw);
        if (mounted) debugPrint('Register: raw exception message="$raw" detectedNetwork=$detected');
        if (detected) {
          errorMsg = 'Temporary network error. Please check your connection and try again.';
          if (mounted) debugPrint('Register: raw error (network-like): $raw');
        } else {
          errorMsg = raw;
        }
      }
  _emitFriendlyError(e, errorMsg);
  if (mounted) debugPrint('Register: error emitted: $errorMsg');
    } finally {
      // Ensure loading dialog is dismissed exactly once
      try {
        if (!_dialogClosed) {
          if (mounted) nav.pop();
          _dialogClosed = true;
        }
      } catch (_) {}
    }
  }

  // Heuristic to detect noisy platform/network error strings so the UI
  // doesn't surface them as raw toasts. This is specific to registration
  // flow to avoid showing long plugin messages to end users while still
  // preserving the raw message in debug logs for troubleshooting.
  bool _isNetworkError(String? message) {
    if (message == null) return false;
    final m = message.toLowerCase();
    final networkIndicators = [
      'network error',
      'timeout',
      'interrupted connection',
      'unreachable host',
      'socketexception',
      'host lookup',
      'network is unreachable',
      'failed host lookup',
      'connection timed out',
    ];
    for (final s in networkIndicators) {
      if (m.contains(s)) return true;
    }
    return false;
  }

  void _emitFriendlyError(Object? raw, [String? fallback]) {
    final rawStr = raw?.toString();
    if (_isNetworkError(rawStr)) {
      debugPrint('Register: raw error (network-like): $rawStr');
      EventBus.instance.emitError('Temporary network error. Please check your connection and try again.');
      return;
    }
    final msg = fallback ?? rawStr ?? 'Registration failed. Please try again.';
    debugPrint('Register: error emitted (raw): $rawStr');
    EventBus.instance.emitError(msg);
  }

  @override
  Widget build(BuildContext context) {
  // responsive helpers (width available if needed)
  // ignore: unused_local_variable
  final width = MediaQuery.of(context).size.width; // intentionally unused helper

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Create account', style: Theme.of(context).textTheme.titleLarge),
                        SizedBox(height: 8),
                        Text('Fill the form to create a new account', style: Theme.of(context).textTheme.bodyMedium),
                        SizedBox(height: 20),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(labelText: 'EMAIL', prefixIcon: Icon(Icons.email)),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Please enter email';
                            final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
                            if (!emailRegex.hasMatch(value)) return 'Please enter a valid email';
                            return null;
                          },
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'PASSWORD',
                            prefixIcon: Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter password';
                            if (v.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'CONFIRM PASSWORD',
                            prefixIcon: Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please confirm password';
                            if (v != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(labelText: 'PHONE (optional)', prefixIcon: Icon(Icons.phone)),
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length < 7) return 'Phone number too short';
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          height: 45,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            onPressed: (!_firebaseReady) ? null : _submit,
                            child: Text('SIGN UP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                        if (_firebaseInitError != null) ...[
                          SizedBox(height: 12),
                          Text('Firebase init error: $_firebaseInitError', style: TextStyle(color: Colors.red)),
                        ],
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already registered?'),
                            TextButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage(title: 'Login'))),
                              child: Text('Login', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}