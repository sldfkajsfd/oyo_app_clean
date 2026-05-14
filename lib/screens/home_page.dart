import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? 'test-dev-user';

    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 대타 요청 리스트'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sub_requests')
            .where('userId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('등록한 대타 요청이 없습니다.'));
          }

          final docs = snapshot.data!.docs;

          // 🔄 startTime 기준 정렬 (null 방지)
          docs.sort((a, b) {
            final aTime = (a['startTime'] as Timestamp?)?.toDate() ?? DateTime(9999);
            final bTime = (b['startTime'] as Timestamp?)?.toDate() ?? DateTime(9999);
            return aTime.compareTo(bTime);
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final start = (data['startTime'] as Timestamp?)?.toDate();
              final end = (data['endTime'] as Timestamp?)?.toDate();
              final reason = data['reason'] ?? '사유 없음';
              final status = data['status'] ?? '대기';

              final formattedDate = start != null
                  ? DateFormat('yyyy-MM-dd').format(start)
                  : '날짜 없음';
              final formattedStart = start != null
                  ? DateFormat('a h:mm', 'ko').format(start)
                  : '?';
              final formattedEnd = end != null
                  ? DateFormat('a h:mm', 'ko').format(end)
                  : '?';

              return ListTile(
                title: Text('$formattedDate ($formattedStart ~ $formattedEnd)'),
                subtitle: Text(reason),
                trailing: Text(
                  _statusText(status),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _statusText(String status) {
    switch (status) {
      case '승인':
        return '✅ 승인';
      case '거절':
        return '❌ 거절';
      default:
        return '⏳ 대기 중';
    }
  }
}
