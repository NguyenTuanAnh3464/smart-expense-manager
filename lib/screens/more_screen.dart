import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_ui.dart';
import 'account_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_insight_screen.dart';
import 'basic_setting_screen.dart';
import 'charts_screen.dart';
import 'dashboard_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'profile_setting_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "No Email";

    return Scaffold(
      backgroundColor: AppUi.pageBackground(context),
      appBar: AppBar(
        title: const Text(
          "Khác",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AppPanel(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppUi.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person, color: AppUi.primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Người dùng",
                        style: TextStyle(
                          color: AppUi.secondaryText(context),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppUi.primaryText(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AppSectionTitle(title: "AI"),
          const SizedBox(height: 10),
          AppNavTile(
            icon: Icons.smart_toy_outlined,
            iconColor: AppUi.primaryGreen,
            title: "Trợ lý AI",
            subtitle: "Hỏi đáp về chi tiêu và tiết kiệm",
            onTap: () => openPage(context, const AIChatScreen()),
          ),
          AppNavTile(
            icon: Icons.auto_awesome,
            iconColor: Colors.purple,
            title: "AI Insight",
            subtitle: "Tạo nhận xét tài chính thông minh",
            onTap: () => openPage(context, const AIInsightScreen()),
          ),
          const SizedBox(height: 8),
          const AppSectionTitle(title: "Màn hình mới"),
          const SizedBox(height: 10),
          AppNavTile(
            icon: Icons.dashboard_outlined,
            iconColor: AppUi.primaryGreen,
            title: "Tổng quan",
            subtitle: "Tổng thu, tổng chi và giao dịch từ Firestore",
            onTap: () => openPage(context, const DashboardScreen()),
          ),
          AppNavTile(
            icon: Icons.insert_chart_outlined,
            iconColor: Colors.blue,
            title: "Biểu đồ",
            subtitle: "Danh mục, xu hướng, so sánh",
            onTap: () => openPage(context, const ChartsScreen()),
          ),
          AppNavTile(
            icon: Icons.account_balance_wallet,
            iconColor: AppUi.primaryGreen,
            title: "Tài khoản",
            subtitle: "Tiền mặt, ngân hàng, ví điện tử",
            onTap: () => openPage(context, const AccountScreen()),
          ),
          AppNavTile(
            icon: Icons.person_outline,
            iconColor: Colors.teal,
            title: "Hồ sơ",
            subtitle: email,
            onTap: () => openPage(context, const ProfileScreen()),
          ),
          AppNavTile(
            icon: Icons.manage_accounts_outlined,
            iconColor: Colors.deepPurple,
            title: "Cài đặt hồ sơ",
            subtitle: "Thông tin và tùy chọn hiển thị",
            onTap: () => openPage(context, const ProfileSettingScreen()),
          ),
          const SizedBox(height: 8),
          const AppSectionTitle(title: "Màn hình hiện có"),
          const SizedBox(height: 10),
          AppNavTile(
            icon: Icons.receipt_long,
            iconColor: Colors.orange,
            title: "Giao dịch",
            subtitle: "Màn hình nhập và sửa giao dịch",
            onTap: () => openPage(context, const HomeScreen()),
          ),
          AppNavTile(
            icon: Icons.settings_outlined,
            iconColor: Colors.blueGrey,
            title: "Cài đặt cơ bản",
            subtitle: "Danh mục, lịch, bảo mật, nhắc nhở",
            onTap: () => openPage(context, const BasicSettingScreen()),
          ),
        ],
      ),
    );
  }
}
