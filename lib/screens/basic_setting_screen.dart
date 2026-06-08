import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'category_setting_screen.dart';
import '../services/notification_service.dart';

class BasicSettingScreen extends StatefulWidget {
  const BasicSettingScreen({super.key});

  @override
  State<BasicSettingScreen> createState() => _BasicSettingScreenState();
}

class _BasicSettingScreenState extends State<BasicSettingScreen> {
  static const Color primaryGreen = Color(0xFF168A36);
  static const Color softGreen = Color(0xFFEAF7EE);

  final NumberFormat moneyFormatter = NumberFormat("#,###", "en_US");
  bool isLoading = true;
  Map<String, dynamic> settings = {};

  Map<String, dynamic> get defaultSettings => {
    "initialBalance": 0.0,
    "showInitialBalanceOnCalendar": true,
    "showInitialBalanceOnReport": false,
    "continuousInputMode": false,
    "monthStartDay": 1,
    "yearStartMonth": 1,
    "calendarAmountDisplay": "income_expense",
    "calendarWeekStart": "monday",
    "chartSortOrder": "category_order",
    "startupTab": "input",
    "defaultTransactionType": "expense",
    "passcodeEnabled": false,
    "passcode": "",
    "reminderEnabled": false,
    "reminderTime": "22:00",
  };

  DocumentReference<Map<String, dynamic>>? get settingDoc {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection("user_settings").doc(user.uid);
  }

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    final doc = settingDoc;
    if (user == null || doc == null) {
      setState(() {
        settings = defaultSettings;
        isLoading = false;
      });
      return;
    }

    final snapshot = await doc.get();
    if (!context.mounted) return;

    if (!snapshot.exists) {
      settings = {
        ...defaultSettings,
        "userId": user.uid,
        "updatedAt": FieldValue.serverTimestamp(),
      };
      await doc.set(settings);
      if (!context.mounted) return;
    } else {
      settings = {...defaultSettings, ...snapshot.data()!};
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
    await syncReminderNotification();
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final user = FirebaseAuth.instance.currentUser;
    final doc = settingDoc;
    if (user == null || doc == null) return;
    final previousValue = settings[key];

    if (!mounted) return;
    setState(() {
      settings[key] = value;
    });

    try {
      await doc.set({
        "userId": user.uid,
        key: value,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (key == "reminderEnabled" || key == "reminderTime") {
        await syncReminderNotification();
        if (!mounted) return;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        settings[key] = previousValue;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Không thể lưu cài đặt: $error")));
    }
  }

  Future<void> syncReminderNotification() async {
    await NotificationService.instance.scheduleDailyReminder(
      enabled: settings["reminderEnabled"] == true,
      timeText: settings["reminderTime"]?.toString() ?? "22:00",
    );
  }

  String formatMoney(num value) {
    return "${moneyFormatter.format(value)}đ";
  }

  Future<void> openInitialBalanceDialog() async {
    final parentContext = context;
    final result = await showDialog<double?>(
      context: parentContext,
      builder: (_) => _AmountDialog(
        initialValue: ((settings["initialBalance"] as num?) ?? 0)
            .toStringAsFixed(0),
      ),
    );
    if (!mounted) return;
    if (result == null) return;

    await updateSetting("initialBalance", result);
  }

  Future<void> openPinDialog() async {
    final parentContext = context;
    final result = await showDialog<String?>(
      context: parentContext,
      builder: (_) =>
          _PinDialog(initialValue: settings["passcode"]?.toString()),
    );
    if (!mounted) return;
    if (result == null) return;

    await updateSetting("passcode", result);
  }

  Future<T?> chooseValue<T>({
    required String title,
    required List<_Choice<T>> choices,
  }) {
    final parentContext = context;
    return showDialog<T>(
      context: parentContext,
      builder: (_) => _ChoiceDialog<T>(title: title, choices: choices),
    );
  }

  Future<void> chooseMonthStartDay() async {
    final value = await chooseValue<int>(
      title: "Ngày bắt đầu của tháng",
      choices: [for (var day = 1; day <= 28; day++) _Choice("Ngày $day", day)],
    );
    if (!context.mounted) return;
    if (value != null) await updateSetting("monthStartDay", value);
  }

  Future<void> chooseYearStartMonth() async {
    final value = await chooseValue<int>(
      title: "Tháng bắt đầu của năm",
      choices: [
        for (var month = 1; month <= 12; month++)
          _Choice("Tháng $month", month),
      ],
    );
    if (!context.mounted) return;
    if (value != null) await updateSetting("yearStartMonth", value);
  }

  Future<void> chooseTextSetting({
    required String key,
    required String title,
    required List<_Choice<String>> choices,
  }) async {
    final value = await chooseValue<String>(title: title, choices: choices);
    if (!context.mounted) return;
    if (value != null) await updateSetting(key, value);
  }

  Future<void> pickReminderTime() async {
    final parts = (settings["reminderTime"] ?? "22:00").toString().split(":");
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 22,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    if (!context.mounted) return;
    if (time == null) return;

    final value =
        "${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")}";
    await updateSetting("reminderTime", value);
  }

  void openPage(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softGreen,
      appBar: AppBar(
        title: const Text(
          "Cài đặt cơ bản",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _SettingGroup(
                  children: [
                    _SettingRow(
                      icon: Icons.grid_view,
                      title: "Thêm danh mục",
                      onTap: () => openPage(const CategorySettingScreen()),
                    ),
                  ],
                ),
                _SettingGroup(
                  children: [
                    _SettingRow(
                      icon: Icons.keyboard,
                      title: "Chế độ hỗ trợ nhập liên tục",
                      switchValue: settings["continuousInputMode"] == true,
                      onSwitchChanged: (value) =>
                          updateSetting("continuousInputMode", value),
                    ),
                    _SettingRow(
                      icon: Icons.calendar_month,
                      title: "Số tiền trên Lịch",
                      value: _calendarAmountLabel(
                        settings["calendarAmountDisplay"],
                      ),
                      onTap: () => chooseTextSetting(
                        key: "calendarAmountDisplay",
                        title: "Số tiền trên Lịch",
                        choices: const [
                          _Choice("Thu nhập và Chi tiêu", "income_expense"),
                          _Choice("Chỉ Thu nhập", "income_only"),
                          _Choice("Chỉ Chi tiêu", "expense_only"),
                          _Choice("Không hiển thị", "hidden"),
                        ],
                      ),
                    ),
                    _SettingRow(
                      icon: Icons.calendar_month,
                      title: "Thứ bắt đầu của lịch",
                      value: settings["calendarWeekStart"] == "sunday"
                          ? "Chủ nhật"
                          : "Thứ hai",
                      onTap: () => chooseTextSetting(
                        key: "calendarWeekStart",
                        title: "Thứ bắt đầu của lịch",
                        choices: const [
                          _Choice("Thứ hai", "monday"),
                          _Choice("Chủ nhật", "sunday"),
                        ],
                      ),
                    ),
                    _SettingRow(
                      icon: Icons.pie_chart,
                      title: "Thứ tự hiển thị của đồ thị",
                      value: _chartSortLabel(settings["chartSortOrder"]),
                      onTap: () => chooseTextSetting(
                        key: "chartSortOrder",
                        title: "Thứ tự hiển thị của đồ thị",
                        choices: const [
                          _Choice("Thứ tự danh mục", "category_order"),
                          _Choice("Số tiền cao đến thấp", "amount_desc"),
                          _Choice("Số tiền thấp đến cao", "amount_asc"),
                        ],
                      ),
                    ),
                  ],
                ),
                _SettingGroup(
                  children: [
                    _SettingRow(
                      icon: Icons.push_pin,
                      title: "Tab sẽ mở khi khởi động",
                      value: _startupTabLabel(settings["startupTab"]),
                      onTap: () => chooseTextSetting(
                        key: "startupTab",
                        title: "Tab sẽ mở khi khởi động",
                        choices: const [
                          _Choice("Nhập vào", "input"),
                          _Choice("Lịch", "calendar"),
                          _Choice("Báo cáo", "report"),
                          _Choice("Ngân sách", "budget"),
                          _Choice("Khác", "more"),
                        ],
                      ),
                    ),
                  ],
                ),
                _SettingGroup(
                  children: [
                    _SettingRow(
                      icon: Icons.campaign,
                      title: "Thông báo nhắc nhở",
                      value: settings["reminderTime"]?.toString() ?? "22:00",
                      switchValue: settings["reminderEnabled"] == true,
                      onSwitchChanged: (value) =>
                          updateSetting("reminderEnabled", value),
                      onTap: pickReminderTime,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _calendarAmountLabel(dynamic value) {
    switch (value) {
      case "income_only":
        return "Chỉ Thu nhập";
      case "expense_only":
        return "Chỉ Chi tiêu";
      case "hidden":
        return "Không hiển thị";
      default:
        return "Thu nhập và Chi tiêu";
    }
  }

  String _chartSortLabel(dynamic value) {
    switch (value) {
      case "amount_desc":
        return "Cao đến thấp";
      case "amount_asc":
        return "Thấp đến cao";
      default:
        return "Thứ tự danh mục";
    }
  }

  String _startupTabLabel(dynamic value) {
    switch (value) {
      case "calendar":
        return "Lịch";
      case "report":
        return "Báo cáo";
      case "budget":
        return "Ngân sách";
      case "more":
        return "Khác";
      default:
        return "Nhập vào";
    }
  }
}

class _SettingGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, color: Colors.black12, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;

  const _SettingRow({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.switchValue,
    this.onSwitchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasSwitch = switchValue != null;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: _BasicSettingScreenState.primaryGreen),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: null,
      trailing: hasSwitch
          ? Switch(
              value: switchValue!,
              activeThumbColor: _BasicSettingScreenState.primaryGreen,
              onChanged: onSwitchChanged,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Text(
                      value!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                if (onTap != null)
                  const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  final String initialValue;

  const _AmountDialog({required this.initialValue});

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    final amount = double.tryParse(controller.text.trim()) ?? 0;
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Thiết lập số dư ban đầu"),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: "Số dư",
          suffixText: "đ",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Hủy"),
        ),
        ElevatedButton(
          onPressed: save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _BasicSettingScreenState.primaryGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text("Lưu"),
        ),
      ],
    );
  }
}

class _PinDialog extends StatefulWidget {
  final String? initialValue;

  const _PinDialog({this.initialValue});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue ?? "");
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void save() {
    Navigator.of(context).pop(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Nhập mã PIN 4 số"),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 4,
        obscureText: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Hủy"),
        ),
        ElevatedButton(
          onPressed: save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _BasicSettingScreenState.primaryGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text("Lưu"),
        ),
      ],
    );
  }
}

class _ChoiceDialog<T> extends StatelessWidget {
  final String title;
  final List<_Choice<T>> choices;

  const _ChoiceDialog({required this.title, required this.choices});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = (screenHeight * 0.58).clamp(220.0, 400.0);

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        height: maxHeight,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: choices.length,
          itemBuilder: (context, index) {
            final choice = choices[index];
            return ListTile(
              title: Text(choice.label),
              onTap: () => Navigator.of(context).pop(choice.value),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Hủy"),
        ),
      ],
    );
  }
}

class _Choice<T> {
  final String label;
  final T value;

  const _Choice(this.label, this.value);
}



