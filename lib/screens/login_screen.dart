import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🔥 추가

import '../services/auth_service.dart';
import 'admin_main_navigation_page.dart';
import 'main_navigation_page.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String error = '';

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),
                  const Text(
                    'oyo',
                    style: TextStyle(fontSize: 96, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'on your own',
                    style: TextStyle(fontSize: 18, color: Colors.black87),
                  ),
                  const SizedBox(height: 120),
                  const Text(
                    'Manage your time and money,\non your own',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),

                  // 이메일 입력
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: '이메일'),
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 입력
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: '비밀번호'),
                  ),
                  const SizedBox(height: 16),

                  // 이메일 로그인 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await AuthService.signInWithEmail(
                          emailController.text.trim(),
                          passwordController.text.trim(),
                        );
                        if (!success) {
                          setState(() {
                            error = '로그인 실패! 이메일 또는 비밀번호 확인';
                          });
                        } else {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await handleLoginAndRedirect(context, user);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('이메일로 시작하기'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  /*
                  // 구글 로그인 (나중에 열기)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final user = await AuthService.signInWithGoogle();
                        if (user != null) {
                          await handleLoginAndRedirect(context, user);
                        }
                      },
                      icon: Image.asset('assets/google_logo.png', height: 20),
                      label: const Text('구글로 시작하기'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: Colors.grey),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  */

                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
                    child: const Text('아직 계정이 없으신가요? 회원가입'),
                  ),

                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(error, style: const TextStyle(color: Colors.red)),
                    ),

                  const SizedBox(height: 32),
                  const Text(
                    '로그인하시면 서비스 이용약관 및 개인정보 처리 방침에 동의하게 됩니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> handleLoginAndRedirect(BuildContext context, User user) async {
    final uid = user.uid;
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final doc = await userDocRef.get();
    if (!doc.exists) {
      await userDocRef.set({
        'email': user.email,
        'role': 'staff',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ✅ fcmToken 업데이트 추가
    final fcmToken = await FirebaseMessaging.instance.getToken();
    await userDocRef.update({'fcmToken': fcmToken});

    final role = (await userDocRef.get()).data()?['role'];

    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminMainNavigationPage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      );
    }
  }
}
