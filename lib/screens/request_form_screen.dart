import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String reason = '';

  // 날짜 선택
  Future<void> pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  // 시간 선택
  Future<void> pickTime({required bool isStart}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("대타 요청 등록")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                onChanged: (value) {
                  setState(() {
                    reason = value;
                  });
                },
                decoration: const InputDecoration(
                  labelText: '사유 입력',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: pickDate,
                child: Text(
                  selectedDate == null
                      ? "날짜 선택"
                      : DateFormat('yyyy-MM-dd').format(selectedDate!),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => pickTime(isStart: true),
                child: Text(
                  startTime == null
                      ? "시작 시간 선택"
                      : startTime!.format(context),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => pickTime(isStart: false),
                child: Text(
                  endTime == null
                      ? "종료 시간 선택"
                      : endTime!.format(context),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  print("버튼 눌림");

                  if (selectedDate != null &&
                      startTime != null &&
                      endTime != null) {
                    final doc = {
                      'date': selectedDate!.toIso8601String(),
                      'startTime': startTime!.format(context),
                      'endTime': endTime!.format(context),
                      'reason': reason,
                      'status': 'requested',
                      'createdAt': Timestamp.now(),
                    };

                    await FirebaseFirestore.instance
                        .collection('sub_requests')
                        .add(doc);

                    print("Firestore에 저장 완료됨");

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("요청이 저장되었습니다!")),
                    );

                    await Future.delayed(const Duration(seconds: 2));
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("모든 항목을 입력해 주세요")),
                    );
                  }
                },
                child: const Text("요청 등록"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
