import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart'; // ✅ 추가: 로그아웃 후 이동할 로그인 페이지

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? '알 수 없음';
    final email = user?.email ?? '알 수 없음';
    final TextEditingController feedbackController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 정보'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🙋 UID: $uid'),
              const SizedBox(height: 8),
              Text('📧 이메일: $email'),
              const SizedBox(height: 24),

              // ✅ 로그아웃 버튼
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                child: const Text('로그아웃'),
              ),

              const SizedBox(height: 32),

              const Text('💬 피드백을 남겨주세요'),
              const SizedBox(height: 8),

              // 피드백 입력창
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '불편한 점이나 개선 사항을 자유롭게 작성해주세요.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // 피드백 전송 버튼
              ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;

                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('로그인 상태가 아닙니다')),
                    );
                    return;
                  }

                  if (feedbackController.text.trim().isEmpty) return;

                  await FirebaseFirestore.instance.collection('feedbacks').add({
                    'userId': user.uid,
                    'email': user.email,
                    'message': feedbackController.text.trim(),
                    'createdAt': Timestamp.now(),
                  });

                  feedbackController.clear();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('피드백이 전송되었습니다!')),
                  );
                },
                child: const Text('피드백 전송'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
