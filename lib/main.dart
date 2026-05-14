import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:oyo_app_clean/services/firebase_service.dart';
import 'screens/home_page.dart';
import 'screens/support_request_page.dart';
import 'screens/support_list_page.dart';
import 'screens/admin_request_list_page.dart';


// 🔑 navigatorKey 전역 선언
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 📨 FCM 설정
Future<void> setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.requestPermission();
  String? token = await messaging.getToken();
  print('📱 FCM Token: $token');

  await FirebaseService().saveFcmTokenToFirestore();

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print('🔄 FCM Token refreshed: $newToken');
    await FirebaseService().saveFcmTokenToFirestore();
  });

  // 포그라운드 알림 수신
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📩 [포그라운드] 메시지 수신됨');
    if (message.notification != null) {
      print('🔔 알림: ${message.notification!.title} - ${message.notification!.body}');
    }
    print('📦 데이터: ${message.data}');
  });

  // 백그라운드에서 알림 클릭 시 라우팅
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('📬 [백그라운드] 알림 클릭');
    print('📦 데이터: ${message.data}');

    final routeTarget = message.data['routeTarget'];
    switch (routeTarget) {
      case 'support_request':
        navigatorKey.currentState?.pushNamed('/support-request');
        break;
      case 'admin_request_list':
        navigatorKey.currentState?.pushNamed('/admin-request-list');
        break;
      case 'home':
        navigatorKey.currentState?.pushNamed('/home');
        break;
      case 'support_list':
        navigatorKey.currentState?.pushNamed('/support-list');
        break;
      default:
        print('❓ 알 수 없는 routeTarget: $routeTarget');
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    await initializeDateFormatting('ko');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }

    try {
      final result = await FirebaseAuth.instance.getRedirectResult();
      print("🌐 redirect 결과: ${result.user}");
    } catch (e) {
      print("❌ redirect 처리 중 오류: $e");
    }

    // 앱 종료 상태에서 알림 클릭 후 실행된 경우 처리
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('🕓 [앱 종료 상태] 초기 메시지 수신');
      print('📦 데이터: ${initialMessage.data}');

      final routeTarget = initialMessage.data['routeTarget'];
      Future.delayed(Duration.zero, () {
        switch (routeTarget) {
          case 'support_request':
            navigatorKey.currentState?.pushNamed('/support-request');
            break;
          case 'admin_request_list':
            navigatorKey.currentState?.pushNamed('/admin-request-list');
            break;
          case 'home':
            navigatorKey.currentState?.pushNamed('/home');
            break;
          case 'support_list':
            navigatorKey.currentState?.pushNamed('/support-list');
            break;
        }
      });
    }

    if (!kIsWeb) {
      await setupFCM();
    }

    runApp(const MyApp());
  }, (error, stackTrace) {
    print('🔥 Uncaught error: $error');
    print(stackTrace);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OYO 앱',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      navigatorKey: navigatorKey, // ✅ navigatorKey 등록
      builder: (context, child) {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.notification != null) {
            final title = message.notification!.title ?? '알림';
            final body = message.notification!.body ?? '';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🔔 $title\n$body'),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
        return child!;
      },
      home: const AuthGate(),

      // ✅ 라우팅 설정
      routes: {
        '/support-request': (_) => const SupportRequestPage(),
        '/admin-request-list': (_) => const AdminRequestListPage(),
        '/home': (_) => const HomePage(),
        '/support-list': (_) => const SupportListPage(),
      },
    );
  }
}
