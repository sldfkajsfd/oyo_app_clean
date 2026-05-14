import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'screens/admin_request_list_page.dart';
import 'screens/auth_gate.dart';
import 'screens/home_page.dart';
import 'screens/register_request_page.dart';
import 'services/firebase_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> setupFCM() async {
  if (kIsWeb) return;

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  await FirebaseService().saveFcmTokenToFirestore();

  FirebaseMessaging.instance.onTokenRefresh.listen((_) {
    FirebaseService().saveFcmTokenToFirestore();
  });

  FirebaseMessaging.onMessage.listen((message) {
    final notification = message.notification;
    if (notification == null) return;

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          '${notification.title ?? '알림'}\n${notification.body ?? ''}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

  final initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    scheduleMicrotask(() => _handleMessageNavigation(initialMessage));
  }
}

void _handleMessageNavigation(RemoteMessage message) {
  final routeTarget = message.data['routeTarget'];
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  switch (routeTarget) {
    case 'support_request':
      navigator.pushNamed('/support-request');
      break;
    case 'support_list':
      navigator.pushNamed('/support-list');
      break;
    case 'admin_request_list':
      navigator.pushNamed('/admin-request-list');
      break;
    case 'create_request':
      navigator.pushNamed('/create-request');
      break;
    case 'home':
      navigator.pushNamed('/home');
      break;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await runZonedGuarded(
    () async {
      await initializeDateFormatting('ko');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (kIsWeb) {
        await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        await FirebaseAuth.instance.getRedirectResult();
      }

      await setupFCM();
      runApp(const MyApp());
    },
    (error, stackTrace) {
      debugPrint('Uncaught app error: $error');
      debugPrintStack(stackTrace: stackTrace);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2C7A7B),
      surface: const Color(0xFFF7FAF9),
    );

    return MaterialApp(
      title: 'OYO',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF7FAF9),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF7FAF9),
          foregroundColor: Color(0xFF1A202C),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
      home: const AuthGate(),
      routes: {
        '/home': (_) => const HomePage(),
        '/support-request': (_) => const HomePage(initialTab: 0),
        '/support-list': (_) => const HomePage(initialTab: 2),
        '/create-request': (_) => const RegisterRequestPage(),
        '/admin-request-list': (_) => const AdminRequestListPage(),
      },
    );
  }
}
