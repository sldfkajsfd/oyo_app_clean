import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubRequestListPage extends StatelessWidget {
  const SubRequestListPage({Key? key}) : super(key: key);

@override
Widget build(BuildContext context) {
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return const Scaffold(
      body: Center(
        child: Text(
          '로그인이 필요합니다.',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  final currentUserId = currentUser.uid;

  final query = FirebaseFirestore.instance
      .collection('sub_requests')
      .where('authorId', isNotEqualTo: currentUserId)
      .orderBy('authorId');


    return Scaffold(
      appBar: AppBar(
        title: const Text('대타 요청 목록'),
      ),
      body: StreamBuilder(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('현재 신청 가능한 대타 요청이 없습니다.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('📅 ${data['date'].toString().split("T")[0]}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🕒 ${data['startTime']} ~ ${data['endTime']}'),
                      Text('💬 사유: ${data['reason']}'),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      // 신청 버튼 눌렀을 때 처리
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('신청 버튼 눌림!')),
                      );
                    },
                    child: const Text('신청'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
