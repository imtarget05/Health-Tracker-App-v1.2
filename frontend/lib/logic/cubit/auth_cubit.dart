import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../services/auth_service.dart';

part 'auth_state.dart';

const bool kVerifyWithBackend =
    bool.fromEnvironment('VERIFY_BACKEND', defaultValue: true);

class AuthCubit extends Cubit<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  AuthCubit() : super(AuthInitial()) {
    _initializeAuth();
  }

  // ✅ KHỞI TẠO FIREBASE AUTH
  void _initializeAuth() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        debugPrint('🔥 Firebase user found: ${firebaseUser.email}');
        emit(UserSignIn());
      } else {
        debugPrint('🚫 No Firebase user found');
        emit(UserSignedOut());
      }
    } catch (e) {
      debugPrint('❌ Auth initialization error: $e');
      emit(AuthError('Initialization failed'));
    }
  }

  // ✅ GOOGLE SIGN-IN
  Future<void> signInWithGoogle() async {
    emit(AuthLoading());
    try {
      debugPrint('🔄 Starting Google Sign-In...');

      if (kIsWeb) {
        // ✅ WEB: Dùng popup của Firebase Auth (KHÔNG dùng google_sign_in)
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');

        final authResult = await _auth.signInWithPopup(provider);
        final user = authResult.user;

        if (user != null) {
          final idToken = await user.getIdToken();
          if (idToken != null && kVerifyWithBackend) {
            _authService.verifyFirebaseToken(idToken).catchError((e) {
              debugPrint('⚠️ Backend sync failed but continuing with Firebase');
              return {'success': false};
            });
          }

          if (authResult.additionalUserInfo?.isNewUser == true) {
            emit(IsNewUser(
              googleUser: null, // Web không có GoogleSignInAccount
              credential:
                  authResult.credential as OAuthCredential?, // có thể null
            ));
          } else {
            emit(UserSignIn());
          }
        }
        return; // Quan trọng: dừng tại đây cho nhánh Web
      }

      // ✅ MOBILE (Android/iOS): GIỮ NGUYÊN google_sign_in
      final GoogleSignIn googleSignIn = GoogleSignIn();
      GoogleSignInAccount? googleUser = await googleSignIn.signInSilently();
      googleUser ??= await googleSignIn.signIn();

      if (googleUser == null) {
        emit(AuthError('Google Sign In Cancelled'));
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final authResult = await _auth.signInWithCredential(credential);
      final user = authResult.user;

      if (user != null) {
        final idToken = await user.getIdToken();
        if (idToken != null && kVerifyWithBackend) {
          _authService.verifyFirebaseToken(idToken).catchError((e) {
            debugPrint('⚠️ Backend sync failed but continuing with Firebase');
            return {'success': false};
          });
        }

        if (authResult.additionalUserInfo?.isNewUser == true) {
          emit(IsNewUser(googleUser: googleUser, credential: credential));
        } else {
          emit(UserSignIn());
        }
      }
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');
      emit(AuthError('Google Sign In Failed: ${e.toString()}'));
    }
  }

  // ✅ SIGN OUT
  Future<void> signOut() async {
    emit(AuthLoading());
    try {
      await _auth.signOut();
      emit(UserSignedOut());
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      emit(AuthError(e.toString()));
    }
  }

  // ✅ SIGN UP VỚI EMAIL/PASSWORD (GỬI MAIL XÁC THỰC)
  Future<void> signUpWithEmail(
      String name, String email, String password) async {
    emit(AuthLoading());
    try {
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.sendEmailVerification();

        debugPrint('📧 Verification email sent to: $email');
        emit(UserSingupButNotVerified());
      }
    } catch (e) {
      debugPrint('❌ Sign up error: $e');
      emit(AuthError(e.toString()));
    }
  }

  // ✅ SIGN IN VỚI EMAIL/PASSWORD (CÓ KIỂM TRA XÁC THỰC EMAIL)
  Future<void> signInWithEmail(String email, String password) async {
    emit(AuthLoading());
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      await user?.reload(); // ✅ Cập nhật trạng thái mới nhất
      final refreshedUser = _auth.currentUser;

      debugPrint('🔐 User signed in: ${refreshedUser?.email}');

      if (refreshedUser != null && !refreshedUser.emailVerified) {
        debugPrint('📧 Email not verified');
        emit(UserNotVerified(email: email, password: password));
      } else if (refreshedUser != null) {
        final idToken = await refreshedUser.getIdToken();
        if (idToken != null) {
          _authService.verifyFirebaseToken(idToken).catchError((e) {
            debugPrint('⚠️ Backend sync failed but continuing with Firebase');
            return {'success': false};
          });
        }

        emit(UserSignIn());
      }
    } catch (e) {
      debugPrint('❌ Sign in error: $e');
      emit(AuthError(e.toString()));
    }
  }

  // ✅ RESEND VERIFY EMAIL (GỬI LẠI EMAIL XÁC THỰC)
  Future<void> resendVerificationEmail(String email, String password) async {
    emit(AuthLoading());
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await _auth.signOut();

        debugPrint('📧 Verification email resent to: $email');
        emit(VerificationEmailSent());
      } else {
        emit(AuthError('User is already verified or does not exist.'));
      }
    } catch (e) {
      debugPrint('❌ Resend verification email error: $e');
      emit(AuthError(e.toString()));
    }
  }

  // ✅ KIỂM TRA LẠI EMAIL ĐÃ XÁC THỰC CHƯA
  Future<void> reloadAndCheckVerification() async {
    emit(AuthLoading());
    try {
      final user = _auth.currentUser;
      await user?.reload();
      final refreshed = _auth.currentUser;

      if (refreshed != null && refreshed.emailVerified) {
        emit(UserSignIn());
      } else {
        emit(AuthError('Email is not verified yet.'));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  // ✅ RESET PASSWORD
  Future<void> resetPassword(String email) async {
    emit(AuthLoading());
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      debugPrint('🔎 signInMethods($email): $methods');

      if (!methods.contains('password')) {
        final hint = methods.contains('google.com')
            ? 'This email uses Google Sign-In. Please sign in with Google or link a password first.'
            : 'No Email/Password account found for this email.';
        emit(AuthError(hint));
        return;
      }

      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('📧 Password reset email sent to: $email');
      emit(ResetPasswordSent());
    } on FirebaseAuthException catch (e) {
      emit(AuthError(e.message ?? 'Unknown error'));
    }
  }

  Future<void> createAccountAndLinkItWithGoogleAccount({
    required String email,
    required String password,
  }) async {
    emit(AuthLoading());
    try {
      final user = _auth.currentUser;
      if (user == null) {
        emit(AuthError(
            'No signed-in user to link. Please sign in with Google first.'));
        return;
      }

      final emailCred =
          EmailAuthProvider.credential(email: email, password: password);

      // Liên kết credential email/password vào user đang đăng nhập (Google)
      await user.linkWithCredential(emailCred);

      // Gửi email xác thực (tuỳ luồng của bạn)
      await user.sendEmailVerification();

      // Optional: sync token với backend (không bắt buộc)
      final idToken = await user.getIdToken();
      if (idToken != null) {
        _authService.verifyFirebaseToken(idToken).catchError((e) {
          debugPrint('⚠️ Backend sync failed but continuing with Firebase');
          return {'success': false};
        });
      }

      emit(UserSingupAndLinkedWithGoogle());
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '🔥 linkWithCredential error -> code: ${e.code}, message: ${e.message}');
      String message = e.message ?? 'Link failed';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already in use.';
      } else if (e.code == 'provider-already-linked') {
        message = 'Email/Password provider is already linked to this account.';
      } else if (e.code == 'credential-already-in-use') {
        message = 'These credentials are already used by another account.';
      } else if (e.code == 'requires-recent-login') {
        message = 'Please re-authenticate with Google and try again.';
      } else if (e.code == 'invalid-email') {
        message = 'Email is invalid or empty. Please try again.';
      }
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
