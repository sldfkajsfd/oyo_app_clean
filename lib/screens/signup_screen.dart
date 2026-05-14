import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_main_navigation_page.dart';
import 'main_navigation_page.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController storeCodeController = TextEditingController();

  String selectedRole = 'staff'; // 기본값은 '직원'
  String error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 🔹 이름 입력
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '이름'),
              ),
              const SizedBox(height: 16),

              // 🔹 이메일 입력
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: '이메일'),
              ),
              const SizedBox(height: 16),

              // 🔹 비밀번호 입력
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호'),
              ),
              const SizedBox(height: 16),

              // 🔹 매장 코드 입력
              TextField(
                controller: storeCodeController,
                decoration: const InputDecoration(labelText: '매장 코드'),
              ),
              const SizedBox(height: 16),

              // 🔹 역할 선택 (직원 / 점장)
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('점장')),
                  DropdownMenuItem(value: 'staff', child: Text('직원')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
                decoration: const InputDecoration(labelText: '회원 유형'),
              ),
              const SizedBox(height: 24),

              // 🔹 회원가입 버튼
              ElevatedButton(
                onPressed: _handleSignUp,
                child: const Text('회원가입 완료'),
              ),

              // 🔹 오류 메시지
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child:
                      Text(error, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    setState(() {
      error = '';
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user == null) throw Exception('회원 생성 실패');
      final uid = user.uid;

      final storeCode = storeCodeController.text.trim();
      String storeId;

      if (selectedRole == 'admin') {
        // 🔹 점장: 매장 신규 생성
        await FirebaseFirestore.instance.collection('stores').doc(storeCode).set({
          'storeId': storeCode,
          'storeName': '루프 베이커리 카페', // or 추후 수정 가능
        });
        storeId = storeCode;
      } else {
        // 🔹 직원: 매장 코드 유효성 검사
        final storeDoc = await FirebaseFirestore.instance
            .collection('stores')
            .doc(storeCode)
            .get();

        if (!storeDoc.exists) {
          throw Exception('유효하지 않은 매장 코드입니다.');
        }

        storeId = storeDoc.id;
      }

      // 🔹 Firestore에 사용자 정보 저장
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'userName': nameController.text.trim(),
        'email': emailController.text.trim(),
        'role': selectedRole,
        'storeId': storeId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔹 사용자 role에 따라 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => selectedRole == 'admin'
              ? const AdminMainNavigationPage()
              : const MainNavigationPage(),
        ),
      );
    } catch (e) {
      setState(() {
        error = '회원가입 실패: ${e.toString()}';
      });
    }
  }
}
