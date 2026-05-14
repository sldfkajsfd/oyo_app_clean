import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminRequestListPage extends StatefulWidget {
  const AdminRequestListPage({super.key});

  @override
  State<AdminRequestListPage> createState() => _AdminRequestListPageState();
}

class _AdminRequestListPageState extends State<AdminRequestListPage> {
  List<Map<String, dynamic>> requestDataList = [];
  String? storeId;

  @override
  void initState() {
    super.initState();
    fetchStoreIdAndRequests();
  }

  Future<void> fetchStoreIdAndRequests() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      storeId = userDoc['storeId'];
      await fetchRequests();
    }
  }

  Future<void> fetchRequests() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('applications')
        .where('status', isEqualTo: '대기')
        .get();

    final List<Map<String, dynamic>> tempList = [];

    for (var appDoc in snapshot.docs) {
      final requestId = appDoc['requestId'];
      final applicantName = appDoc['applicantName'] ?? '알 수 없음';
      final appId = appDoc.id;

      final requestDoc = await FirebaseFirestore.instance
          .collection('sub_requests')
          .doc(requestId)
          .get();

      if (requestDoc.exists) {
        final requestData = requestDoc.data()!;

        if (requestData['storeId'] != storeId) continue;

        tempList.add({
          'appId': appId,
          'requestId': requestId,
          'applicantName': applicantName,
          'applicantId': appDoc['applicantId'],
          'requesterName': requestData['userName'] ?? '알 수 없음',
          'requesterId': requestData['userId'],
          'reason': requestData['reason'] ?? '사유 없음',
          'startTime': requestData['startTime'],
          'endTime': requestData['endTime'],
        });
      }
    }

    setState(() {
      requestDataList = tempList;
    });
  }

  Future<void> handleAction({
    required String appId,
    required String requestId,
    required String applicantName,
    required String applicantId,
    required String requesterName,
    required String requesterId,
    required String reason,
    required String status,
    required Timestamp startTimestamp,
    required Timestamp endTimestamp,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('정말 $status하시겠습니까?'),
        content: Text('요청을 $status 처리합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('아니요')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('네')),
        ],
      ),
    );

    if (confirm != true) return;

    final appRef = FirebaseFirestore.instance.collection('applications').doc(appId);
    final requestRef = FirebaseFirestore.instance.collection('sub_requests').doc(requestId);

    await appRef.update({'status': status});
    await requestRef.update({'status': status});

    // ✅ 승인일 경우에만 substitution_schedule 등록
    if (status == '승인') {
      if (storeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('에러: 점주의 storeId 정보를 불러올 수 없습니다.')),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('substitution_schedule').add({
        'date': DateFormat('yyyy-MM-dd').format(startTimestamp.toDate()),
        'startTime': DateFormat('a h:mm', 'ko').format(startTimestamp.toDate()),
        'endTime': DateFormat('a h:mm', 'ko').format(endTimestamp.toDate()),
        'fromUser': requesterName,
        'toUser': applicantName,
        'reason': reason,
        'status': 'approved',
        'createdAt': FieldValue.serverTimestamp(),
        'storeId': storeId, // ✅ 누락 없이 저장
      });
    }

    // ✅ 알림 전송
    final timeFormat = DateFormat('M월 d일 a h:mm', 'ko');
    final periodText =
        '${timeFormat.format(startTimestamp.toDate())}~${DateFormat('h:mm', 'ko').format(endTimestamp.toDate())}';

    final requesterMessage = '$periodText 대타 요청이 $status되었습니다!';
    final applicantMessage = '$periodText 대타 지원이 $status되었습니다!';

    final batch = FirebaseFirestore.instance.batch();

    final requesterNotiRef = FirebaseFirestore.instance
        .collection('users')
        .doc(requesterId)
        .collection('notifications')
        .doc();

    final applicantNotiRef = FirebaseFirestore.instance
        .collection('users')
        .doc(applicantId)
        .collection('notifications')
        .doc();

    batch.set(requesterNotiRef, {
      'message': requesterMessage,
      'createdAt': Timestamp.now(),
      'type': 'approval',
      'read': false,
      'requestId': requestId,
    });

    batch.set(applicantNotiRef, {
      'message': applicantMessage,
      'createdAt': Timestamp.now(),
      'type': 'approval',
      'read': false,
      'requestId': requestId,
    });

    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$status 처리 완료')));
    await fetchRequests();
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd a h:mm', 'ko');

    return Scaffold(
      appBar: AppBar(title: const Text('대타 요청 승인/거절')),
      body: requestDataList.isEmpty
          ? const Center(child: Text('승인할 요청이 없습니다.'))
          : ListView.builder(
              itemCount: requestDataList.length,
              itemBuilder: (context, index) {
                final item = requestDataList[index];
                final start = (item['startTime'] as Timestamp).toDate();
                final end = (item['endTime'] as Timestamp).toDate();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text('🙋 ${item['requesterName']} → 🙆 ${item['applicantName']}'),
                    subtitle: Text(
                      '근무: ${formatter.format(start)} ~ ${formatter.format(end)}\n사유: ${item['reason']}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => handleAction(
                            appId: item['appId'],
                            requestId: item['requestId'],
                            applicantName: item['applicantName'],
                            applicantId: item['applicantId'],
                            requesterName: item['requesterName'],
                            requesterId: item['requesterId'],
                            reason: item['reason'],
                            status: '승인',
                            startTimestamp: item['startTime'],
                            endTimestamp: item['endTime'],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => handleAction(
                            appId: item['appId'],
                            requestId: item['requestId'],
                            applicantName: item['applicantName'],
                            applicantId: item['applicantId'],
                            requesterName: item['requesterName'],
                            requesterId: item['requesterId'],
                            reason: item['reason'],
                            status: '거절',
                            startTimestamp: item['startTime'],
                            endTimestamp: item['endTime'],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
