import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mvp_shared.dart';
import '../services/auth_service.dart';
import '../services/store_onboarding_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _feedbackController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _sendFeedback() async {
    final user = FirebaseAuth.instance.currentUser;
    final message = _feedbackController.text.trim();
    if (user == null || message.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance.collection('feedbacks').add({
        'userId': user.uid,
        'email': user.email,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _feedbackController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('피드백을 보냈어요.')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: EmptyState(
          title: '로그인이 필요해요',
          message: '내 정보를 보려면 로그인해 주세요.',
          icon: Icons.lock_outline,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('내 정보')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future:
            FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? {};
          final userName =
              (data['userName'] ?? user.displayName ?? '알바생').toString();
          final role = data['role']?.toString();
          final storeId = data['storeId']?.toString() ?? '';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(user.email ?? ''),
                      const Divider(height: 28),
                      _ProfileRow(label: '역할', value: roleLabel(role)),
                      const SizedBox(height: 8),
                      _ProfileRow(
                        label: '매장',
                        value: storeId.isEmpty ? '매장 미연결' : storeId,
                      ),
                    ],
                  ),
                ),
              ),
              if (storeId.isNotEmpty)
                _StoreInfoCard(
                  storeId: storeId,
                  userId: user.uid,
                  isManager: isManagerRole(role),
                ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '테스트 피드백',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1주 테스트 중 불편한 점을 남겨주세요.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _feedbackController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: '예: 지원 상태가 더 잘 보이면 좋겠어요.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _isSending ? null : _sendFeedback,
                          child: Text(_isSending ? '전송 중' : '보내기'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () => AuthService.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('로그아웃'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StoreInfoCard extends StatelessWidget {
  const _StoreInfoCard({
    required this.storeId,
    required this.userId,
    required this.isManager,
  });

  final String storeId;
  final String userId;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      future:
          isManager
              ? StoreOnboardingService().ensureInviteCodeForStore(
                storeId: storeId,
                createdBy: userId,
              )
              : FirebaseFirestore.instance
                  .collection('stores')
                  .doc(storeId)
                  .get(),
      builder: (context, snapshot) {
        final storeData = snapshot.data?.data();
        if (storeData == null) return const SizedBox.shrink();

        final storeName = (storeData['storeName'] ?? '매장').toString();
        final inviteCode = (storeData['inviteCode'] ?? '').toString();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isManager ? '직원에게 아래 초대 코드를 공유해 주세요.' : '같은 매장 요청만 보여요.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                if (isManager && inviteCode.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      inviteCode,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: inviteCode),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('초대 코드를 복사했어요.')),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('복사'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 82,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
