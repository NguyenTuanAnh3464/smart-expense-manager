import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_ui.dart';
import 'account_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_insight_screen.dart';
import 'basic_setting_screen.dart';
import 'charts_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'saving_goal_screen.dart';
import 'theme_setting_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
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
            icon: Icons.insights_outlined,
            iconColor: Colors.deepPurple,
            title: "AI Insight",
            subtitle: "Phân tích thói quen thu chi bằng AI",
            onTap: () => openPage(context, const AIInsightScreen()),
          ),
          const SizedBox(height: 18),
          const AppSectionTitle(title: "Tài khoản"),
          const SizedBox(height: 10),
          AppNavTile(
            icon: Icons.person_outline,
            iconColor: Colors.teal,
            title: "Hồ sơ",
            subtitle: email,
            onTap: () => openPage(context, const ProfileScreen()),
          ),
          AppNavTile(
            icon: Icons.account_balance_wallet,
            iconColor: AppUi.primaryGreen,
            title: "Tài khoản tiền",
            subtitle: "Tiền mặt, ngân hàng, ví điện tử",
            onTap: () => openPage(context, const AccountScreen()),
          ),
          AppNavTile(
            icon: Icons.savings_outlined,
            iconColor: AppUi.primaryGreen,
            title: "Mục tiêu tiết kiệm",
            subtitle: "Theo dõi tiến độ tiết kiệm cá nhân",
            onTap: () => openPage(context, const SavingGoalScreen()),
          ),
          const SizedBox(height: 18),
          const AppSectionTitle(title: "Ứng dụng"),
          const SizedBox(height: 10),
          AppNavTile(
            icon: Icons.insert_chart_outlined,
            iconColor: Colors.blue,
            title: "Biểu đồ",
            subtitle: "Danh mục, xu hướng, so sánh",
            onTap: () => openPage(context, const ChartsScreen()),
          ),
          AppNavTile(
            icon: Icons.settings_outlined,
            iconColor: Colors.blueGrey,
            title: "Cài đặt cơ bản",
            subtitle: "Danh mục, lịch, bảo mật, nhắc nhở",
            onTap: () => openPage(context, const BasicSettingScreen()),
          ),
          AppNavTile(
            icon: Icons.dark_mode_outlined,
            iconColor: Colors.indigo,
            title: "Theme sáng/tối",
            subtitle: "Chọn giao diện sáng, tối hoặc theo hệ thống",
            onTap: () => openPage(context, const ThemeSettingScreen()),
          ),
          const SizedBox(height: 18),
          const AppSectionTitle(title: "Thoát"),
          const SizedBox(height: 10),
          AppNavTile(
            icon: Icons.logout,
            iconColor: Colors.red,
            title: "Đăng xuất",
            subtitle: "Thoát khỏi tài khoản hiện tại",
            onTap: () => logout(context),
          ),
        ],
      ),
    );
  }
}

