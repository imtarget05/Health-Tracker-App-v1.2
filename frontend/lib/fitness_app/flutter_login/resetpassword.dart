import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';
import '../../firebase_options.dart';

import 'login.dart';


class ResetPasswordPage extends StatefulWidget {
  ResetPasswordPage({super.key, required this.title});
  final String title;
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _firebaseReady = false;
  String? _firebaseInitError;

  @override
  void initState() {
    super.initState();
    _ensureFirebaseInitialized();
    _initUniLinks();
  }

  StreamSubscription? _sub;

  void _initUniLinks() async {
    // Listen for incoming deep links while app is running
    _sub = uriLinkStream.listen((Uri? uri) {
      if (uri == null) return;
      // Expecting oobCode as query param
      final oob = uri.queryParameters['oobCode'] ?? uri.queryParameters['oobcode'] ?? uri.queryParameters['code'];
      if (oob != null) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResetPasswordConfirmPage(oobCode: oob)));
          });
        }
      }
    }, onError: (err) {
      // ignore for now
    });
    // Handle initial link if app opened from cold start
    try {
      final initial = await getInitialUri();
      if (initial != null) {
        final oob = initial.queryParameters['oobCode'] ?? initial.queryParameters['oobcode'] ?? initial.queryParameters['code'];
        if (oob != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResetPasswordConfirmPage(oobCode: oob)));
          });
        }
      }
    } catch (_) {}
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
  _sub?.cancel();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Please enter your email';
    if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // capture context-bound objects before async gaps
    final scaffold = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() => _isLoading = true);
    try {
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        } catch (initErr) {
          setState(() => _isLoading = false);
          scaffold.showSnackBar(
            SnackBar(content: Text('Firebase init failed: $initErr')),
          );
          return;
        }
      }
      // Send password reset email with continue URL that returns to the app.
      // IMPORTANT: replace the iOS bundle id below with your app's real bundle id
      final actionCodeSettings = ActionCodeSettings(
        // Use the Firebase project's default authorized domain to avoid allowlist errors.
        // Replace with your own hosted redirect if you prefer.
        url: 'https://healthy-tracker-target.firebaseapp.com/reset',
        handleCodeInApp: true,
        iOSBundleId: 'com.example.best_flutter_ui_templates', // <-- REPLACE with your iOS bundle id (Info.plist)
        androidPackageName: 'com.example.best_flutter_ui_templates', // <-- REPLACE with your Android package name
        androidInstallApp: false,
        androidMinimumVersion: '12',
      );

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
        actionCodeSettings: actionCodeSettings,
      );
  setState(() => _isLoading = false);
  scaffold.showSnackBar(
        const SnackBar(content: Text('Password reset link sent. Check your email.')),
      );
      await Future.delayed(const Duration(milliseconds: 700));
  nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
  setState(() => _isLoading = false);
  String msg = 'Failed to send reset email.';
      if (e.code == 'user-not-found') {
        msg = 'No user found for that email.';
      } else if (e.message != null) {
        msg = e.message!;
      }
      scaffold.showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      scaffold.showSnackBar(
        const SnackBar(content: Text('An error occurred. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Reset Password',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the email address associated with your account and we will send a link to reset your password.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    decoration: const InputDecoration(
                      labelText: 'EMAIL',
                      labelStyle: TextStyle(fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: (_isLoading || !_firebaseReady) ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'RESET PASSWORD',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_firebaseInitError != null) ...[
                    Text('Firebase init error: $_firebaseInitError', style: TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                  ],
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Back to Login'),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// Embedded confirm page (previously in reset_password_confirm.dart)
class ResetPasswordConfirmPage extends StatefulWidget {
  final String oobCode;
  const ResetPasswordConfirmPage({super.key, required this.oobCode});

  @override
  State<ResetPasswordConfirmPage> createState() => _ResetPasswordConfirmPageState();
}

class _ResetPasswordConfirmPageState extends State<ResetPasswordConfirmPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.confirmPasswordReset(code: widget.oobCode, newPassword: _passwordController.text.trim());
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Failed to reset password'; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set new password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'New password'),
                    obscureText: true,
                    validator: (v) {
                      if (v == null || v.trim().length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const CircularProgressIndicator() : const Text('Reset password'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}