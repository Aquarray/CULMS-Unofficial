import 'package:flutter/material.dart';
import '../common/custom_bottom_nav.dart';
import 'courses/courses_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'settings/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 1; // Center: Dashboard is the default prominent landing tab

  final List<Widget> _screens = const [
    CoursesScreen(),   // Left: MyCourses
    DashboardScreen(), // Center: Dashboard
    SettingsScreen(),  // Right: Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTabSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
