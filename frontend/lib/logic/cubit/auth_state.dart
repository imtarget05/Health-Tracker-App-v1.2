// lib/core/logic/cubit/auth_state.dart
// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'auth_cubit.dart';

@immutable
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class UserSignIn extends AuthState {}

class UserSignedOut extends AuthState {}

class UserNotVerified extends AuthState {
  final String email;
  final String password;
  UserNotVerified({
    required this.email,
    required this.password,
  });
}

class UserSingupButNotVerified extends AuthState {}

class IsNewUser extends AuthState {
  final GoogleSignInAccount? googleUser;
  final OAuthCredential? credential;
  IsNewUser({this.googleUser, this.credential});
}

class UserSingupAndLinkedWithGoogle extends AuthState {}

class ResetPasswordSent extends AuthState {}

class VerificationEmailSent extends AuthState {}

class PasswordResetEmailSent extends AuthState {}

// ✅ OTP STATES
class OTPSent extends AuthState {
  final String email;
  OTPSent({
    required this.email,
  });
}

class OTPVerified extends AuthState {}

class PasswordResetSuccess extends AuthState {}

// ✅ PHONE AUTH STATES
class PhoneCodeSent extends AuthState {
  final String verificationId;
  final int? resendToken;
  PhoneCodeSent({
    required this.verificationId,
    this.resendToken,
  });
}

class PhoneVerified extends AuthState {}

class PhoneAuthError extends AuthState {
  final String message;
  PhoneAuthError(this.message);
}

// ✅ ERROR STATE
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}
