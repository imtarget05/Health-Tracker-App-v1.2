import 'dart:io';
import 'package:best_flutter_ui_templates/app_theme.dart';
import 'package:best_flutter_ui_templates/fitness_app/my_diary/my_diary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'fitness_app/fitness_app_home_screen.dart';

import 'fitness_app/input_information/welcome_screen.dart';
import 'fitness_app/input_information/select_goal_screen.dart';

import 'fitness_app/welcome/onboarding_screen.dart';
import 'fitness_app/flutter_login/login.dart';
import 'fitness_app/flutter_login/register.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/screens/chat_screen.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/themes/my_theme.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/providers/chat_provider.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/providers/settings_provider.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'screens/health_check_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'fitness_app/debug/profile_sync_debug.dart';
import 'services/profile_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize profile sync service (Hive + optional firebase init inside service)
  try {
    await ProfileSyncService.instance.init();
  } catch (e) {
    print('ProfileSyncService init warning: $e');
  }
  // Log xác nhận Firebase đã khởi tạo
  print('✅ Firebase initialized: [32m${Firebase.apps.isNotEmpty}[0m');
  try {
    await dotenv.load();
  } catch (e) {
    print('Warning: .env not found or failed to load: $e');
  }
  ChatProvider.initHive().catchError((e) {
    print('Warning: ChatProvider.initHive failed: $e');
  });
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: !kIsWeb && Platform.isAndroid
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    return MaterialApp(
      title: 'Flutter UI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: AppTheme.textTheme,
        platform: TargetPlatform.iOS,
        dividerTheme: DividerThemeData(color: Color(0xFFE0E0E0)),
      ),
      routes: {
        'register': (context) => RegisterPage(title: 'Register'),
        'health-check': (context) => HealthCheckScreen(),
  'profile-sync-debug': (context) => const ProfileSyncDebugPage(),
      },
      home: LoginPage(title: 'Login'),
    );
  }
}


class HexColor extends Color {
  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));

  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }
}
