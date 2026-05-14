import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RegisterRequestPage extends StatefulWidget {
  const RegisterRequestPage({Key? key}) : super(key: key);

  @override
  State<RegisterRequestPage> createState() => _RegisterRequestPageState();
}

class _RegisterRequestPageState extends State<RegisterRequestPage> {
  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  final reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('대타 요청하기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📅 날짜 선택'),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (date != null) setState(() => selectedDate = date);
              },
              child: Text(
                selectedDate != null
                    ? selectedDate!.toString().split(' ')[0]
                    : '날짜 선택',
              ),
            ),
            const SizedBox(height: 16),
            const Text('⏱ 시작 시간'),
            ElevatedButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) setState(() => startTime = time);
              },
              child: Text(
                startTime != null
                    ? startTime!.format(context)
                    : '시작 시간 선택',
              ),
            ),
            const SizedBox(height: 16),
            const Text('⏱ 종료 시간'),
            ElevatedButton(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) setState(() => endTime = time);
              },
              child: Text(
                endTime != null
                    ? endTime!.format(context)
                    : '종료 시간 선택',
              ),
            ),
            const SizedBox(height: 16),
            const Text('📝 사유 (선택)'),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: '예: 병원, 가족 행사 등',
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _submitRequest,
                icon: const Icon(Icons.send),
                label: const Text('대타 요청 등록'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'test-dev-user';

    if (selectedDate == null || startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('날짜와 시간을 모두 입력해주세요')),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final storeId = userDoc['storeId'];
      final userName = userDoc['userName'] ?? '알 수 없음';

      final startDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        startTime!.hour,
        startTime!.minute,
      );

      final endDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        endTime!.hour,
        endTime!.minute,
      );

      // 🔹 대타 요청 저장 (Cloud Function이 알림 처리함)
      await FirebaseFirestore.instance.collection('sub_requests').add({
        'storeId': storeId,
        'userId': uid,
        'userName': userName,
        'reason': reasonController.text.trim(),
        'startTime': Timestamp.fromDate(startDateTime),
        'endTime': Timestamp.fromDate(endDateTime),
        'status': '대기',
        'createdAt': Timestamp.now(),
        'date': DateFormat('yyyy-MM-dd').format(selectedDate!),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 대타 요청이 등록되었습니다!')),
      );

      setState(() {
        selectedDate = null;
        startTime = null;
        endTime = null;
        reasonController.clear();
      });
    } catch (e) {
      print('❌ 에러 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('에러 발생: $e')),
      );
    }
  }
}
