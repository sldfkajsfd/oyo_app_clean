import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SupportRequestPage extends StatefulWidget {
  const SupportRequestPage({Key? key}) : super(key: key);

  @override
  State<SupportRequestPage> createState() => _SupportRequestPageState();
}

class _SupportRequestPageState extends State<SupportRequestPage> {
  late final String userId;
  String? userStoreId;
  List<QueryDocumentSnapshot> filteredDocs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('로그인되지 않은 사용자입니다.');
    }
    userId = user.uid;
    loadUserStoreIdAndFetch();
  }

  Future<void> loadUserStoreIdAndFetch() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      userStoreId = userDoc['storeId'];

      if (userStoreId == null || userStoreId!.isEmpty) {
        throw Exception('사용자의 storeId가 없습니다.');
      }

      await fetchFilteredRequests();
    } catch (e) {
      debugPrint('storeId 로딩 중 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> fetchFilteredRequests() async {
    try {
      if (userStoreId == null) return;

      // 내가 지원한 요청 ID들
      final myAppliedSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .where('applicantId', isEqualTo: userId)
          .get();

      final myAppliedRequestIds = myAppliedSnapshot.docs
          .map((doc) => doc['requestId'] as String)
          .toSet();

      // 누군가 이미 지원한 요청 ID들 (대기 상태만)
      final alreadyAppliedSnapshot = await FirebaseFirestore.instance
          .collection('applications')
          .where('status', isEqualTo: '대기')
          .get();

      final alreadyAppliedRequestIds = alreadyAppliedSnapshot.docs
          .map((doc) => doc['requestId'] as String)
          .toSet();

      // 현재 업장(storeId)에서 등록된 전체 대기 요청
      final allRequestsSnapshot = await FirebaseFirestore.instance
          .collection('sub_requests')
          .where('status', isEqualTo: '대기')
          .where('storeId', isEqualTo: userStoreId)
          .get();

      // 필터링: 1) 본인 요청 제외 2) 내가 지원한 요청 제외 3) 누군가 이미 지원한 요청 제외
      final filtered = allRequestsSnapshot.docs.where((doc) {
        final requestId = doc.id;
        final requestUserId = doc['userId'];

        final isMyRequest = requestUserId == userId;
        final isAlreadyAppliedByMe = myAppliedRequestIds.contains(requestId);
        final isAlreadyAppliedBySomeone = alreadyAppliedRequestIds.contains(requestId);

        return !isMyRequest && !isAlreadyAppliedByMe && !isAlreadyAppliedBySomeone;
      }).toList();

      if (mounted) {
        setState(() {
          filteredDocs = filtered;
        });
      }
    } catch (e) {
      debugPrint('요청 필터링 중 오류: $e');
    }
  }

  Future<void> _applyToRequest(String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final requestSnapshot = await FirebaseFirestore.instance
        .collection('sub_requests')
        .doc(requestId)
        .get();

    if (!requestSnapshot.exists) return;

    final requestData = requestSnapshot.data()!;
    final storeId = requestData['storeId'] ?? 'unknown';
    final startTime = (requestData['startTime'] as Timestamp).toDate();
    final endTime = (requestData['endTime'] as Timestamp).toDate();
    final requestUserName = requestData['userName'] ?? '직원';

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final applicantName = userDoc['userName'] ?? '알 수 없음';

    await FirebaseFirestore.instance.collection('applications').add({
      'requestId': requestId,
      'applicantId': uid,
      'applicantName': applicantName,
      'status': '대기',
      'appliedAt': Timestamp.now(),
      'storeId': storeId,
    });

    final timeFormat = DateFormat('M월 d일 a h:mm', 'ko');
    final periodText =
        '${timeFormat.format(startTime)}~${DateFormat('h:mm', 'ko').format(endTime)}';

    final message =
        '$applicantName님이 $requestUserName님의 $periodText 대타 요청에 지원하였습니다';

    final managerSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('storeId', isEqualTo: storeId)
        .where('role', isEqualTo: 'admin')
        .limit(1)
        .get();

    if (managerSnapshot.docs.isNotEmpty) {
      final managerId = managerSnapshot.docs.first.id;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(managerId)
          .collection('notifications')
          .add({
        'message': message,
        'createdAt': Timestamp.now(),
        'requestId': requestId,
        'type': 'application',
        'read': false,
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('지원 완료되었습니다!')),
    );

    await fetchFilteredRequests(); // 다시 새로고침
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('대타 지원하기')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredDocs.isEmpty
              ? const Center(child: Text('지원할 수 있는 요청이 없습니다.'))
              : ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final docId = filteredDocs[index].id;
                    final reason = data['reason'] ?? '사유 없음';

                    final startTime = (data['startTime'] as Timestamp).toDate();
                    final endTime = (data['endTime'] as Timestamp).toDate();

                    final formatter = DateFormat('yyyy-MM-dd HH:mm');
                    final formattedStart = formatter.format(startTime);
                    final formattedEnd = formatter.format(endTime);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(reason),
                        subtitle: Text('$formattedStart ~ $formattedEnd'),
                        trailing: ElevatedButton(
                          onPressed: () => _applyToRequest(docId),
                          child: const Text('지원하기'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
