import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'budget_screen.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'more_screen.dart';
import 'report_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;
  static const Color primaryGreen = Color(0xFF168A36);

  final List<Widget> screens = const [
    DashboardScreen(),
    CalendarScreen(),
    ReportScreen(),
    BudgetScreen(),
    MoreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    loadStartupTab();
  }

  Future<void> loadStartupTab() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection("user_settings")
        .doc(user.uid)
        .get();
    if (!context.mounted) return;
    if (!snapshot.exists) return;

    final tab = snapshot.data()?["startupTab"]?.toString();
    final nextIndex = switch (tab) {
      "calendar" => 1,
      "report" => 2,
      "budget" => 3,
      "more" => 4,
      _ => 0,
    };

    setState(() {
      currentIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final navTheme = Theme.of(context).bottomNavigationBarTheme;

    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: navTheme.backgroundColor,
        selectedItemColor: navTheme.selectedItemColor ?? primaryGreen,
        unselectedItemColor: navTheme.unselectedItemColor,
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
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Ngân sách',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Khác'),
        ],
      ),
    );
  }
}
