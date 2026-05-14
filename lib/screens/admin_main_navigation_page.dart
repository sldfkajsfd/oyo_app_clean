import 'package:flutter/material.dart';

import 'admin_request_list_page.dart';
import 'profile_page.dart';

class AdminMainNavigationPage extends StatefulWidget {
  const AdminMainNavigationPage({super.key});

  @override
  State<AdminMainNavigationPage> createState() =>
      _AdminMainNavigationPageState();
}

class _AdminMainNavigationPageState extends State<AdminMainNavigationPage> {
  int _selectedIndex = 0;

  final _pages = const [AdminRequestListPage(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '대시보드',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}
