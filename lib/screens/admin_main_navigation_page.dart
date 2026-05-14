import 'package:flutter/material.dart';
import 'admin_home_page.dart';
import 'admin_request_list_page.dart';
import 'profile_page.dart'; // 기존 직원용과 공유

class AdminMainNavigationPage extends StatefulWidget {
  const AdminMainNavigationPage({Key? key}) : super(key: key);

  @override
  State<AdminMainNavigationPage> createState() => _AdminMainNavigationPageState();
}

class _AdminMainNavigationPageState extends State<AdminMainNavigationPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    AdminHomePage(),         // 📅 대타 스케줄 표
    AdminRequestListPage(),  // ✅ 대타 요청 승인/거절
    ProfilePage(),           // 🙋 내 정보
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_alt),
            label: '요청 리스트',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}
