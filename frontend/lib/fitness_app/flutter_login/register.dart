import 'package:flutter/material.dart';
import './login.dart';
import '../../services/backend_api.dart';
import '../../services/auth_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../profile/edit_profile.dart';
import '../welcome/onboarding_screen.dart';

class RegisterPage extends StatefulWidget {
  RegisterPage({super.key, required this.title});
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
    final scaffold = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    setState(() {});

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

  final res = await BackendApi.signup(
        fullName: email.split('@').first,
        email: email,
        password: password,
        phone: phone.isEmpty ? null : phone,
      );

  // backend returns token in body; store it for later API calls
  final backendToken = res['token'] as String?;
  if (backendToken != null) AuthStorage.saveToken(backendToken);

      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        } catch (initErr) {
          if (mounted) nav.pop();
          scaffold.showSnackBar(
            SnackBar(content: Text('Firebase init failed: $initErr')),
          );
          return;
        }
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

  // After sign-in, ensure the user completes profile once if missing
  if (mounted) nav.pop();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        scaffold.showSnackBar(const SnackBar(content: Text('Đăng ký thành công')));
        nav.pushReplacement(MaterialPageRoute(builder: (_) => OnboardingScreen()));
        return;
      }

      // Check firestore for existing profile info
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

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
              title: const Text('Yêu cầu hoàn thành hồ sơ'),
              content: const Text('Bạn phải hoàn thành hồ sơ để tiếp tục sử dụng ứng dụng. Muốn thử lại hay đăng xuất?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Thử lại')),
                TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Đăng xuất')),
              ],
            ),
          );
          if (choice == false) {
            await FirebaseAuth.instance.signOut();
            return;
          }
        }
      }

  if (mounted) scaffold.showSnackBar(const SnackBar(content: Text('Đăng ký thành công')));
  if (mounted) nav.pushReplacement(MaterialPageRoute(builder: (_) => OnboardingScreen()));
    } on FirebaseAuthException catch (e) {
  if (mounted) nav.pop();
      String errorMsg = 'Đăng ký thất bại';
      if (e.code == 'email-already-in-use' || e.code == 'email-already-exists') {
        errorMsg = 'Email đã tồn tại.';
      } else if (e.code == 'weak-password') {
        errorMsg = 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      } else if (e.code == 'invalid-email') {
        errorMsg = 'Email không hợp lệ.';
      } else {
        errorMsg = e.message ?? errorMsg;
      }
      scaffold.showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } catch (e) {
  if (mounted) nav.pop();
  String errorMsg = 'Đăng ký thất bại';
      if (e.toString().contains('email-already-exists') || e.toString().contains('email-already-in-use')) {
        errorMsg = 'Email đã tồn tại.';
      } else if (e.toString().contains('weak-password')) {
        errorMsg = 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      } else if (e.toString().contains('invalid-email')) {
        errorMsg = 'Email không hợp lệ.';
      } else {
        errorMsg = e.toString();
      }
      scaffold.showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
  // responsive helpers (width available if needed)
  final width = MediaQuery.of(context).size.width;

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