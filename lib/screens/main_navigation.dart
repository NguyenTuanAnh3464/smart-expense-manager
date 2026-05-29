import 'package:flutter/material.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'report_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;
  static const Color primaryGreen = Color(0xFF168A36);
  static const Color softGreen = Color(0xFFEAF7EE);

  final List<Widget> screens = const [
    HomeScreen(),
    CalendarScreen(),
    ReportScreen(),
    AccountPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        elevation: 10,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Báo cáo',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _MainNavigationState.softGreen,
      appBar: AppBar(
        title: const Text('Lịch'),
        backgroundColor: _MainNavigationState.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Màn hình lịch', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _MainNavigationState.softGreen,
      appBar: AppBar(
        title: const Text('Tài khoản'),
        backgroundColor: _MainNavigationState.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Màn hình tài khoản', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
