import 'dart:io';
import 'package:best_flutter_ui_templates/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;



import 'fitness_app/flutter_login/login.dart';
import 'fitness_app/flutter_login/register.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:best_flutter_ui_templates/fitness_app/notification/Chatbox/providers/chat_provider.dart';
import 'screens/health_check_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as cf;
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'fitness_app/debug/profile_sync_debug.dart';
import 'services/profile_sync_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'fitness_app/camera/models/scan_result.dart';
import 'fitness_app/camera/services/db_service.dart';
import 'widgets/global_toast.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  // Optionally enable Firebase Emulator wiring via --dart-define=USE_FIREBASE_EMULATOR=1
  final useEmulator = const String.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: '0') == '1';
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (useEmulator) {
    try {
      // Firestore emulator default host: localhost:8080
      cf.FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    } catch (e) {
      print('Could not wire Firestore emulator: $e');
    }
    try {
      // Auth emulator default host: localhost:9099
      fa.FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    } catch (e) {
      print('Could not wire Auth emulator: $e');
    }
    print('⚠️ Firebase emulator wiring enabled (USE_FIREBASE_EMULATOR=1)');
  }
  // Initialize profile sync service (Hive + optional firebase init inside service)
  try {
    await ProfileSyncService.instance.init();
  } catch (e) {
    print('ProfileSyncService init warning: $e');
  }
  // Ensure ScanResult adapter registered and scan_history box opened so
  // the Camera/History features can persist and read scan entries.
  try {
    // Hive is initialized inside ProfileSyncService.init() via Hive.initFlutter();
    // register the generated adapter so we can open a typed box.
    Hive.registerAdapter(ScanResultAdapter());
    await DBService.init();
    // attempt to repair any missing image paths so history thumbnails persist
    await DBService.repairMissingPaths();
  } catch (e) {
    print('Warning: DBService.init failed: $e');
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
  runApp(const GlobalToast(child: MyApp()));
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
