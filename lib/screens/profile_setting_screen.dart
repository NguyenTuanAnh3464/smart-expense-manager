import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_profile_model.dart';
import '../services/profile_service.dart';
import '../services/theme_service.dart';
import '../widgets/app_ui.dart';

class ProfileSettingScreen extends StatefulWidget {
  const ProfileSettingScreen({super.key});

  @override
  State<ProfileSettingScreen> createState() => _ProfileSettingScreenState();
}

class _ProfileSettingScreenState extends State<ProfileSettingScreen> {
  final ProfileService profileService = ProfileService();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final photoController = TextEditingController();

  bool isLoading = true;
  String currency = "VND";
  bool compactDashboard = true;
  bool monthlySummary = true;
  bool spendingReminder = false;
  bool biometricLock = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    photoController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    await profileService.ensureProfileDocument();
    final profile = await profileService.getProfileOnce();
    final user = FirebaseAuth.instance.currentUser;
    if (!mounted) return;

    applyProfile(profile, user);
    setState(() {
      isLoading = false;
    });
  }

  void applyProfile(UserProfileModel? profile, User? user) {
    nameController.text = profile?.name.trim().isNotEmpty == true
        ? profile!.name
        : (user?.displayName?.trim().isNotEmpty == true
              ? user!.displayName!
              : "Người dùng");
    emailController.text = profile?.email.trim().isNotEmpty == true
        ? profile!.email
        : user?.email ?? "";
    phoneController.text = profile?.phone ?? user?.phoneNumber ?? "";
    photoController.text = profile?.photoURL ?? user?.photoURL ?? "";
    currency = profile?.currency ?? "VND";
    compactDashboard = profile?.compactDashboard ?? true;
    monthlySummary = profile?.monthlySummary ?? true;
    spendingReminder = profile?.spendingReminder ?? false;
    biometricLock = profile?.biometricLock ?? false;
  }

  Future<void> saveProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      await profileService.updateProfile({
        "name": nameController.text.trim().isEmpty
            ? "Người dùng"
            : nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "photoURL": photoController.text.trim().isEmpty
            ? null
            : photoController.text.trim(),
        "currency": currency,
        "compactDashboard": compactDashboard,
        "monthlySummary": monthlySummary,
        "spendingReminder": spendingReminder,
        "biometricLock": biometricLock,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã lưu cài đặt hồ sơ")));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Không thể lưu hồ sơ: $error")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUi.pageBackground(context),
      appBar: AppBar(
        title: const Text(
          "Cài đặt hồ sơ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(title: "Thông tin cá nhân"),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: "Tên hiển thị",
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "Email",
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: "Số điện thoại",
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: photoController,
                        decoration: const InputDecoration(
                          labelText: "Photo URL",
                          prefixIcon: Icon(Icons.image_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: currency,
                        decoration: const InputDecoration(
                          labelText: "Tiền tệ mặc định",
                          prefixIcon: Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: "VND",
                            child: Text("VND - Việt Nam"),
                          ),
                          DropdownMenuItem(value: "USD", child: Text("USD")),
                          DropdownMenuItem(value: "EUR", child: Text("EUR")),
                        ],
                        onChanged: (value) {
                          setState(() {
                            currency = value ?? "VND";
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _ThemeModeTile(),
                      const Divider(height: 1, indent: 58),
                      _SettingSwitchTile(
                        icon: Icons.dashboard_customize_outlined,
                        title: "Dashboard gọn",
                        subtitle: "Lưu vào users/{uid}.compactDashboard",
                        value: compactDashboard,
                        onChanged: (value) {
                          setState(() {
                            compactDashboard = value;
                          });
                        },
                      ),
                      const Divider(height: 1, indent: 58),
                      _SettingSwitchTile(
                        icon: Icons.summarize_outlined,
                        title: "Tóm tắt hàng tháng",
                        subtitle: "Lưu vào users/{uid}.monthlySummary",
                        value: monthlySummary,
                        onChanged: (value) {
                          setState(() {
                            monthlySummary = value;
                          });
                        },
                      ),
                      const Divider(height: 1, indent: 58),
                      _SettingSwitchTile(
                        icon: Icons.notifications_active_outlined,
                        title: "Nhắc nhập giao dịch",
                        subtitle: "Lưu vào users/{uid}.spendingReminder",
                        value: spendingReminder,
                        onChanged: (value) {
                          setState(() {
                            spendingReminder = value;
                          });
                        },
                      ),
                      const Divider(height: 1, indent: 58),
                      _SettingSwitchTile(
                        icon: Icons.lock_outline,
                        title: "Khóa bảo mật",
                        subtitle: "Lưu vào users/{uid}.biometricLock",
                        value: biometricLock,
                        onChanged: (value) {
                          setState(() {
                            biometricLock = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: saveProfile,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text(
                      "Lưu cài đặt",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppUi.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeService = ThemeScope.of(context);
    final currentMode = themeService.themeMode;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          currentMode == ThemeMode.dark
              ? Icons.dark_mode_outlined
              : Icons.light_mode_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        "Giao diện",
        style: TextStyle(
          color: AppUi.primaryText(context),
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text("Sáng"),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text("Tối"),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto_outlined),
              label: Text("Hệ thống"),
            ),
          ],
          selected: {currentMode},
          onSelectionChanged: (selection) {
            themeService.setThemeMode(selection.first);
          },
        ),
      ),
    );
  }
}

class _SettingSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppUi.primaryGreen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      secondary: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppUi.primaryGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppUi.primaryGreen),
      ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppUi.primaryText(context),
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: AppUi.secondaryText(context)),
      ),
    );
  }
}
