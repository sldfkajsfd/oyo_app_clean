import 'package:flutter/material.dart';
import 'register_request_page.dart';
import 'support_request_page.dart';
import 'profile_page.dart';
import 'package:oyo_app_clean/screens/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oyo_app_clean/screens/support_request_page.dart';
import 'package:oyo_app_clean/screens/support_list_page.dart';



class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({Key? key}) : super(key: key);

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
  HomePage(),              // 🏠 내가 등록한 대타 요청 리스트
  RegisterRequestPage(),   // 📝 대타 요청 등록
  SupportListPage(), // 나의 대타 지원 리스트
  SupportRequestPage(),    // 🤝 대타 지원
  ProfilePage(),           // 👤 내 정보

  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
 appBar: AppBar(
  title: const Text('OYO'),
  actions: [
    IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
      },
    ),
  ],
),



      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
  currentIndex: _selectedIndex,
  onTap: (index) {
    setState(() {
      _selectedIndex = index;
    });
  },
  backgroundColor: Colors.white, // 바 배경색
  selectedItemColor: Colors.teal, // 선택된 아이템 색
  unselectedItemColor: Colors.grey, // 선택 안 된 아이템 색
  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: '홈',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.add),
      label: '요청 등록',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.support_agent),
      label: '대타 지원',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.history), // ✅ 너가 선택한 아이콘
      label: '지원 내역',
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
