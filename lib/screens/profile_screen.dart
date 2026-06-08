import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user_profile_model.dart';
import '../services/account_service.dart';
import '../services/profile_service.dart';
import '../services/transaction_service.dart';
import '../widgets/app_ui.dart';
import 'account_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_insight_screen.dart';
import 'basic_setting_screen.dart';
import 'charts_screen.dart';
import 'login_screen.dart';
import 'profile_setting_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService profileService = ProfileService();
  final AccountService accountService = AccountService();
  final TransactionService transactionService = TransactionService();

  @override
  void initState() {
    super.initState();
    profileService.ensureProfileDocument();
  }

  void openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Đăng xuất"),
          content: const Text("Bạn có chắc muốn đăng xuất không?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Đăng xuất"),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<_ProfileStats> loadStats() async {
    final accounts = await accountService.getAccountsOnce();
    final transactions = await transactionService.getTransactionsOnce();
    return _ProfileStats(
      accountCount: accounts.length,
      transactionCount: transactions.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      return const Scaffold(body: Center(child: Text("Chưa đăng nhập")));
    }

    return Scaffold(
      backgroundColor: AppUi.pageBackground(context),
      appBar: AppBar(
        title: const Text(
          "Hồ sơ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<UserProfileModel?>(
        stream: profileService.getProfileStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          final profile = snapshot.data;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _ProfileHeader(user: authUser, profile: profile),
              const SizedBox(height: 14),
              FutureBuilder<_ProfileStats>(
                future: loadStats(),
                builder: (context, statsSnapshot) {
                  final stats = statsSnapshot.data;
                  return Row(
                    children: [
                      Expanded(
                        child: _ProfileStat(
                          title: "Tài khoản",
                          value: stats?.accountCount.toString() ?? "...",
                          icon: Icons.account_balance_wallet,
                          color: AppUi.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProfileStat(
                          title: "Giao dịch",
                          value: stats?.transactionCount.toString() ?? "...",
                          icon: Icons.receipt_long,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              const AppSectionTitle(title: "AI"),
              const SizedBox(height: 10),
              AppNavTile(
                icon: Icons.smart_toy_outlined,
                iconColor: AppUi.primaryGreen,
                title: "Trợ lý AI",
                subtitle: "Hỏi đáp về chi tiêu cá nhân",
                onTap: () => openPage(const AIChatScreen()),
              ),
              AppNavTile(
                icon: Icons.auto_awesome,
                iconColor: Colors.purple,
                title: "AI Insight",
                subtitle: "Nhận xét tài chính từ dữ liệu gần đây",
                onTap: () => openPage(const AIInsightScreen()),
              ),
              const SizedBox(height: 8),
              const AppSectionTitle(title: "Tài chính"),
              const SizedBox(height: 10),
              AppNavTile(
                icon: Icons.account_balance_wallet,
                iconColor: AppUi.primaryGreen,
                title: "Tài khoản tiền",
                subtitle: "Đọc và lưu bằng Firestore",
                onTap: () => openPage(const AccountScreen()),
              ),
              AppNavTile(
                icon: Icons.insert_chart_outlined,
                iconColor: Colors.blue,
                title: "Biểu đồ",
                subtitle: "Tính từ giao dịch Firestore",
                onTap: () => openPage(const ChartsScreen()),
              ),
              const SizedBox(height: 8),
              const AppSectionTitle(title: "Cài đặt"),
              const SizedBox(height: 10),
              AppNavTile(
                icon: Icons.person_outline,
                iconColor: AppUi.primaryGreen,
                title: "Cài đặt hồ sơ",
                subtitle: profile?.email ?? authUser.email ?? "No Email",
                onTap: () => openPage(const ProfileSettingScreen()),
              ),
              AppNavTile(
                icon: Icons.settings_outlined,
                iconColor: Colors.orange,
                title: "Cài đặt cơ bản",
                subtitle: "Danh mục, lịch, ngân sách, nhắc nhở",
                onTap: () => openPage(const BasicSettingScreen()),
              ),
              AppNavTile(
                icon: Icons.logout,
                iconColor: Colors.red,
                title: "Đăng xuất",
                subtitle: "Thoát khỏi tài khoản hiện tại",
                onTap: confirmLogout,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User user;
  final UserProfileModel? profile;

  const _ProfileHeader({required this.user, required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile?.name.trim().isNotEmpty == true
        ? profile!.name
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!
              : "Người dùng");
    final email = profile?.email.trim().isNotEmpty == true
        ? profile!.email
        : user.email ?? "No Email";
    final photoURL = profile?.photoURL ?? user.photoURL;
    final createdAt = profile?.createdAt ?? user.metadata.creationTime;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppUi.lightGreen, AppUi.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppUi.primaryGreen.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: photoURL == null || photoURL.isEmpty
                ? null
                : NetworkImage(photoURL),
            child: photoURL == null || photoURL.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 34)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    "Tham gia ${DateFormat("dd/MM/yyyy").format(createdAt)}",
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ProfileStat({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppUi.secondaryText(context)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "Không thể tải hồ sơ: $message",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

class _ProfileStats {
  final int accountCount;
  final int transactionCount;

  const _ProfileStats({
    required this.accountCount,
    required this.transactionCount,
  });
}
