import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_navigation_page.dart';
import 'login_screen.dart';
import 'admin_main_navigation_page.dart';
import '../services/firebase_service.dart'; // ✅ FCM 저장 서비스 import

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 로딩 중일 때
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 로그인 안 된 경우
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // 로그인된 유저
        final user = snapshot.data!;
        final uid = user.uid;

        // ✅ Firestore에서 role을 가져와서 분기
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const LoginScreen(); // 예외 상황: 유저 문서 없음
            }

            final role = snapshot.data!.get('role');

            // ✅ 로그인 직후 FCM 토큰 저장
            FirebaseService().saveFcmTokenToFirestore();

            if (role == 'admin') {
              return const AdminMainNavigationPage();
            } else {
              return const MainNavigationPage();
            }
          },
        );
      },
    );
  }
}
