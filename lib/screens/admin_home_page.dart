import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_request_list_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<Map<String, dynamic>>> substitutionMap = {};
  String? storeId;

  @override
  void initState() {
    super.initState();
    _fetchStoreIdAndLoadData();
  }

  Future<void> _fetchStoreIdAndLoadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data();
    storeId = userData?['storeId'];

    if (storeId == null) return;

    await _loadSubstitutionRequests();
  }

  Future<void> _loadSubstitutionRequests() async {
    final Map<String, List<Map<String, dynamic>>> tempMap = {};

    // 🔹 substitution_schedule 불러오기
    final subSnapshot = await FirebaseFirestore.instance
        .collection('substitution_schedule')
        .where('status', isEqualTo: 'approved')
        .where('storeId', isEqualTo: storeId)
        .get();

    for (var doc in subSnapshot.docs) {
      final data = doc.data();
      final dateStr = data['date'] ?? '';
      if (!tempMap.containsKey(dateStr)) {
        tempMap[dateStr] = [];
      }
      tempMap[dateStr]!.add(data);
    }

    print('✅ substitution_schedule 불러오기 완료: ${subSnapshot.docs.length}건');

    setState(() {
      substitutionMap = tempMap;
    });
  }

  bool hasSchedule(DateTime date) {
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return substitutionMap.containsKey(dateStr);
  }

  void showScheduleDetail(BuildContext context, DateTime date) {
    final dateStr =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final data = substitutionMap[dateStr] ?? [];

    if (data.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$dateStr 대타 내역'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.map((item) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🟧 ${item['startTime']} ~ ${item['endTime']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${item['fromUser']} → ${item['toUser']}'),
                    Text('사유: ${item['reason']}'),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _navigateToRequestList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminRequestListPage()),
    ).then((_) {
      _loadSubstitutionRequests();
    });
  }

  Widget _buildCalendarDay(DateTime day, bool hasEvent, {required bool isToday}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = day;
          _focusedDay = day;
        });
        showScheduleDetail(context, day);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: hasEvent ? Colors.orange : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: hasEvent ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isToday)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.circle,
                size: 6,
                color: Colors.blue,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('대타 스케줄 표'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: '승인/거절 요청 보기',
            onPressed: _navigateToRequestList,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TableCalendar(
          locale: 'ko_KR',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.month,
          calendarBuilders: CalendarBuilders(
            defaultBuilder: (context, day, focusedDay) {
              final hasEvent = hasSchedule(day);
              return _buildCalendarDay(day, hasEvent, isToday: false);
            },
            todayBuilder: (context, day, focusedDay) {
              final hasEvent = hasSchedule(day);
              return _buildCalendarDay(day, hasEvent, isToday: true);
            },
          ),
        ),
      ),
    );
  }
}
