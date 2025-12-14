import 'package:flutter/material.dart';
import './login.dart';
import '../../services/backend_api.dart';
import '../../services/auth_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';
import '../../services/google_auth_service.dart';
import '../../services/facebook_auth_service.dart';
import '../welcome/onboarding_screen.dart';

class RegisterPage extends StatefulWidget {
  RegisterPage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  _RegisterPageState createState() => _RegisterPageState();
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
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Firebase init failed: $initErr')),
          );
          return;
        }
      }
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng ký thành công')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => OnboardingScreen()),
      );
    } on FirebaseAuthException catch (e) {
      Navigator.of(context).pop();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    } catch (e) {
      Navigator.of(context).pop();
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
      ScaffoldMessenger.of(context).showSnackBar(
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
                        const SizedBox(height: 12),
                          const SizedBox(height: 16),
                          // Social signup buttons (reuse same backend flows)
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                                  try {
                                    final svc = GoogleAuthService();
                                    final backendBase = BackendApi.baseUrl;
                                    final res = await svc.signInToBackend(backendBase);
                                    if (res != null) {
                                      final token = res['token'] as String?;
                                      if (token != null) AuthStorage.saveToken(token);
                                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OnboardingScreen()));
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-up failed: $e')));
                                  } finally {
                                    Navigator.of(context).pop();
                                  }
                                },
                                icon: Image.asset('assets/images/google_logo.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.g_mobiledata)),
                                label: const Text('Google'),
                                style: OutlinedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(color: Colors.grey), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), minimumSize: const Size(140, 44)),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                                  try {
                                    final svc = FacebookAuthService();
                                    final backendBase = BackendApi.baseUrl;
                                    final res = await svc.signInToBackend(backendBase);
                                    if (res != null) {
                                      final token = res['token'] as String?;
                                      if (token != null) AuthStorage.saveToken(token);
                                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OnboardingScreen()));
                                    }
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Facebook sign-up failed: $e')));
                                  } finally {
                                    Navigator.of(context).pop();
                                  }
                                },
                                icon: Image.asset('assets/images/facebook_logo.png', width: 20, height: 20, errorBuilder: (c,e,s) => const Icon(Icons.facebook)),
                                label: const Text('Facebook'),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1877F2), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), minimumSize: const Size(140, 44)),
                              ),
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