import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SupportListPage extends StatefulWidget {
  const SupportListPage({Key? key}) : super(key: key);

  @override
  State<SupportListPage> createState() => _SupportListPageState();
}

class _SupportListPageState extends State<SupportListPage> {
  late String userId;
  List<Map<String, dynamic>> mySupportData = [];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('로그인되지 않은 사용자입니다.');
    }

    userId = user.uid;
    fetchMySupports();
  }

  Future<void> fetchMySupports() async {
    final supportSnapshot = await FirebaseFirestore.instance
        .collection('applications')
        .where('applicantId', isEqualTo: userId)
        .get();

    final List<Map<String, dynamic>> result = [];

    for (var appDoc in supportSnapshot.docs) {
      final requestId = appDoc['requestId'];
      final status = appDoc['status'] ?? '대기';

      final requestDoc = await FirebaseFirestore.instance
          .collection('sub_requests')
          .doc(requestId)
          .get();

      if (requestDoc.exists) {
        final requestData = requestDoc.data() as Map<String, dynamic>;
        requestData['status'] = status; // 상태를 덮어쓰기
        result.add(requestData);
      }
    }

    setState(() {
      mySupportData = result;
    });
  }

  Widget _buildSupportItem(Map<String, dynamic> data) {
    final reason = data['reason'] ?? '사유 없음';
    final status = data['status'] ?? '대기';

    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    DateTime? startTime, endTime;

    try {
      final rawStart = data['startTime'];
      final rawEnd = data['endTime'];

      if (rawStart is Timestamp) {
        startTime = rawStart.toDate();
      } else if (rawStart is String) {
        startTime = DateFormat('hh:mm a').parse(rawStart);
      }

      if (rawEnd is Timestamp) {
        endTime = rawEnd.toDate();
      } else if (rawEnd is String) {
        endTime = DateFormat('hh:mm a').parse(rawEnd);
      }
    } catch (e) {
      return ListTile(
        title: const Text('시간 파싱 오류'),
        subtitle: Text('요청 데이터 오류\n$e'),
      );
    }

    final formattedStart = formatter.format(startTime!);
    final formattedEnd = formatter.format(endTime!);

    // 상태별 아이콘과 색상 처리
    Icon statusIcon;
    Color statusColor;
    String statusText;

    switch (status) {
      case '승인':
        statusIcon = const Icon(Icons.check_circle, color: Colors.green);
        statusColor = Colors.green;
        statusText = '승인';
        break;
      case '거절':
        statusIcon = const Icon(Icons.cancel, color: Colors.red);
        statusColor = Colors.red;
        statusText = '거절';
        break;
      default:
        statusIcon = const Icon(Icons.hourglass_empty, color: Colors.brown);
        statusColor = Colors.brown;
        statusText = '대기 중';
    }

    return ListTile(
      title: Text('$formattedStart ~ $formattedEnd'),
      subtitle: Text(reason),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          statusIcon,
          const SizedBox(width: 4),
          Text(statusText, style: TextStyle(color: statusColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('나의 대타 지원 리스트'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: mySupportData.isEmpty
            ? const Center(child: Text('지원한 요청이 없습니다.'))
            : ListView.builder(
                itemCount: mySupportData.length,
                itemBuilder: (context, index) {
                  return _buildSupportItem(mySupportData[index]);
                },
              ),
      ),
    );
  }
}
