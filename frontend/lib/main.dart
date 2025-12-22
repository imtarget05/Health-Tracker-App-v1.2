import 'dart:io';
import 'package:best_flutter_ui_templates/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;



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
import 'fitness_app/camera/services/suggestion_service.dart';
import 'widgets/global_toast.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  // Optionally enable Firebase Emulator wiring via --dart-define=USE_FIREBASE_EMULATOR=1
  final useEmulator = const String.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: '0') == '1';
  // Allow overriding emulator host via dart-define FIREBASE_EMULATOR_HOST
  final definedHost = const String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (useEmulator) {
    try {
      final host = definedHost.isNotEmpty
          ? definedHost
          : (!kIsWeb && Platform.isAndroid ? '10.0.2.2' : 'localhost');
      // Firestore emulator default host: host:8080
      cf.FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      // Auth emulator default host: host:9099
      fa.FirebaseAuth.instance.useAuthEmulator(host, 9099);
      if (kDebugMode) debugPrint('⚠️ Firebase emulator wiring enabled (USE_FIREBASE_EMULATOR=1) host=$host');
    } catch (e) {
      if (kDebugMode) debugPrint('Could not wire Firebase emulator: $e');
    }
  }
  // Initialize profile sync service (Hive + optional firebase init inside service)
  try {
    await ProfileSyncService.instance.init();
  } catch (e) {
    if (kDebugMode) debugPrint('ProfileSyncService init warning: $e');
  }
  // Ensure ScanResult adapter registered and scan_history box opened so
  // the Camera/History features can persist and read scan entries.
  try {
    // Hive is initialized inside ProfileSyncService.init() via Hive.initFlutter();
    Hive.registerAdapter(ScanResultAdapter());
  // Ensure scan_history box is opened so HistoryScreen/DBService can read entries
  await DBService.init();
    // open suggestions box used to store 'slot:none' suggestions
    await SuggestionService.init();
  } catch (e) {
    if (kDebugMode) debugPrint('Warning: SuggestionService/DBService init failed: $e');
  }
  // attempt to repair any missing image paths so history thumbnails persist
  try {
    await DBService.repairMissingPaths();
  } catch (e) {
    if (kDebugMode) debugPrint('DBService.repairMissingPaths failed: $e');
  }
  // Log xác nhận Firebase đã khởi tạo
  if (kDebugMode) debugPrint('✅ Firebase initialized: ${Firebase.apps.isNotEmpty}');
  try {
    await dotenv.load();
  } catch (e) {
    if (kDebugMode) debugPrint('Warning: .env not found or failed to load: $e');
  }
  try {
    // Ensure chat-related Hive boxes/adapters are initialized before the UI
    // builds (so widgets that call Hive.box(...) won't throw).
    await ChatProvider.initHive();
  } catch (e) {
    if (kDebugMode) debugPrint('Warning: ChatProvider.initHive failed: $e');
  }
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
      hexColor = 'FF$hexColor';
    }
    return int.parse(hexColor, radix: 16);
  }
}
