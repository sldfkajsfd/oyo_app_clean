import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../mvp_shared.dart';

class RegisterRequestPage extends StatefulWidget {
  const RegisterRequestPage({super.key});

  @override
  State<RegisterRequestPage> createState() => _RegisterRequestPageState();
}

class _RegisterRequestPageState extends State<RegisterRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _memoController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      locale: const Locale('ko'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          isStart
              ? _startTime ?? TimeOfDay.now()
              : _endTime ?? _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('날짜와 시간을 모두 선택해 주세요.')));
      return;
    }

    final start = combineDateAndTime(_selectedDate!, _startTime!);
    final end = combineDateAndTime(_selectedDate!, _endTime!);
    if (!end.isAfter(start)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('종료 시간은 시작 시간보다 늦어야 해요.')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final userData = userDoc.data();
      final storeId = userData?['storeId']?.toString();
      if (storeId == null || storeId.isEmpty) {
        throw Exception('먼저 매장에 참여해 주세요.');
      }

      final userName =
          (userData?['userName'] ?? user.displayName ?? '알바생').toString();

      await FirebaseFirestore.instance.collection('sub_requests').add({
        'storeId': storeId,
        'requesterId': user.uid,
        'userId': user.uid,
        'requesterName': userName,
        'userName': userName,
        'reason': _reasonController.text.trim(),
        'memo': _memoController.text.trim(),
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(end),
        'date': dateKey(start),
        'status': MvpStatus.open,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('요청이 올라갔어요'),
              content: const Text('지원자가 생기면 매니저가 확인하고 한 명을 확정해요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
      );

      if (!mounted) return;
      setState(() {
        _selectedDate = null;
        _startTime = null;
        _endTime = null;
        _reasonController.clear();
        _memoController.clear();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cleanError(error))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('대타 요청하기')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '부탁은 앱이 대신 전할게요',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '필요한 일정만 차분히 적으면 같은 매장 알바생에게 보여요.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              _PickerTile(
                icon: Icons.calendar_today_outlined,
                label: '날짜',
                value:
                    _selectedDate == null
                        ? '선택해 주세요'
                        : formatDate(_selectedDate),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.schedule_outlined,
                      label: '시작 시간',
                      value: _startTime?.format(context) ?? '선택',
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PickerTile(
                      icon: Icons.flag_outlined,
                      label: '종료 시간',
                      value: _endTime?.format(context) ?? '선택',
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: '사유',
                  hintText: '예: 병원 예약, 가족 일정, 시험 준비',
                ),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? '사유를 간단히 적어 주세요.'
                            : null,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _memoController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  hintText: '인수인계가 필요한 내용이 있으면 적어 주세요.',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _submitRequest,
                icon: const Icon(Icons.send_outlined),
                label: Text(_isSaving ? '등록 중...' : '요청 올리기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
