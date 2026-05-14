import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'request_form_screen.dart'; // ✅ 등록 화면 import 꼭 해줘야 해!

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return '승인';
      case 'rejected':
        return '거절';
      default:
        return '대기';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OYO - 대타 요청 리스트')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sub_requests')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('요청한 내역이 없습니다.'));
          }

          final requests = snapshot.data!.docs;

          return ListView.separated(
            itemCount: requests.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final data = requests[index].data() as Map<String, dynamic>;
              final date = DateFormat('yyyy-MM-dd').format(DateTime.parse(data['date']));
              final time = '${data['startTime']} ~ ${data['endTime']}';
              final reason = data['reason'] ?? '';
              final status = data['status'] ?? 'requested';

              return ListTile(
                title: Text('$date ($time)'),
                subtitle: Text(reason.isNotEmpty ? reason : '사유 없음'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor(status),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_getStatusLabel(status)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
