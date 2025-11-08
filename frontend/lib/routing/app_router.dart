import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../logic/cubit/auth_cubit.dart';
import '../screens/create_password/ui/create_password.dart';
import '../screens/forget/ui/forget_screen.dart';
import '../screens/home/ui/home_screen.dart';
import '../screens/login/ui/login_screen.dart';
import '../screens/signup/ui/sign_up_screen.dart';
import 'routes.dart';

class AppRouter {
  late AuthCubit authCubit;

  AppRouter() {
    authCubit = AuthCubit();
  }

  Route? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.forgetScreen:
        return MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: authCubit,
            child: const ForgetScreen(), // ✅ THÊM CONST
          ),
        );

      case Routes.homeScreen:
        return MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: authCubit,
            child: const HomeScreen(), // ✅ THÊM CONST
          ),
        );

      case Routes.createPassword:
        final arguments = settings.arguments;
        if (arguments is List && arguments.length >= 2) {
          return MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: authCubit,
              child: CreatePassword(
                googleUser: arguments[0],
                credential: arguments[1],
              ),
            ),
          );
        } else {
          // Fallback nếu arguments không hợp lệ
          return _errorRoute('Invalid arguments for create password');
        }

      case Routes.signupScreen:
        return MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: authCubit,
            child: const SignUpScreen(), // ✅ THÊM CONST
          ),
        );

      case Routes.loginScreen:
        return MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: authCubit,
            child: const LoginScreen(), // ✅ THÊM CONST
          ),
        );

      default:
        // ✅ THÊM DEFAULT CASE
        return _errorRoute('Route ${settings.name} not found');
    }
  }

  // Thêm error route
  Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')), // ✅ THÊM CONST
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}
