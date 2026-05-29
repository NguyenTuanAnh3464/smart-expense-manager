import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

enum _BudgetSaveScope { currentMonth, currentAndFutureMonths }

class BudgetSettingScreen extends StatefulWidget {
  final DateTime currentMonth;

  const BudgetSettingScreen({super.key, required this.currentMonth});

  @override
  State<BudgetSettingScreen> createState() => _BudgetSettingScreenState();
}

class _BudgetSettingScreenState extends State<BudgetSettingScreen> {
  static const Color primaryGreen = Color(0xFF168A36);
  static const Color softGreen = Color(0xFFEAF7EE);
  static const Color lineGreen = Color(0xFFCDE8D4);
  static const String totalBudgetCategory = "Tổng ngân sách";

  final NumberFormat moneyFormatter = NumberFormat("#,###", "en_US");
  final Map<String, double?> amounts = {};
  final Map<String, _ExistingBudget> existingBudgets = {};

  bool includeUnbudgetedExpenses = true;
  bool isLoading = true;
  bool isSaving = false;
  String? settingId;

  final List<_SettingCategory> categories = const [
    _SettingCategory(
      name: "Ăn uống",
      icon: Icons.restaurant,
      color: Colors.orange,
    ),
    _SettingCategory(
      name: "Chi tiêu hằng ngày",
      icon: Icons.local_mall,
      color: primaryGreen,
    ),
    _SettingCategory(
      name: "Quần áo",
      icon: Icons.checkroom,
      color: Colors.blue,
    ),
    _SettingCategory(name: "Mỹ phẩm", icon: Icons.brush, color: Colors.pink),
    _SettingCategory(
      name: "Phí giao lưu",
      icon: Icons.celebration,
      color: Colors.amber,
    ),
    _SettingCategory(
      name: "Y tế",
      icon: Icons.local_hospital,
      color: Colors.green,
    ),
    _SettingCategory(
      name: "Giáo dục",
      icon: Icons.school,
      color: Colors.redAccent,
    ),
    _SettingCategory(
      name: "Tiền điện",
      icon: Icons.flash_on,
      color: Colors.cyan,
    ),
    _SettingCategory(
      name: "Đi lại",
      icon: Icons.directions_bus,
      color: Colors.deepOrange,
    ),
    _SettingCategory(
      name: "Phí liên lạc",
      icon: Icons.phone_android,
      color: Colors.grey,
    ),
    _SettingCategory(name: "Tiền nhà", icon: Icons.home, color: Colors.brown),
    _SettingCategory(name: "Khác", icon: Icons.more_horiz, color: Colors.grey),
  ];

  DateTime get firstDayOfMonth {
    return DateTime(widget.currentMonth.year, widget.currentMonth.month, 1);
  }

  DateTime get lastDayOfMonth {
    return DateTime(widget.currentMonth.year, widget.currentMonth.month + 1, 0);
  }

  String formatMoney(double value) {
    return "${moneyFormatter.format(value)}đ";
  }

  String displayAmount(double? value) {
    if (value == null || value <= 0) return "Chưa đặt";
    return formatMoney(value);
  }

  double get categoryBudgetTotal {
    return categories.fold<double>(
      0,
      (total, category) => total + (amounts[category.name] ?? 0),
    );
  }

  List<DateTime> targetMonthsForScope(_BudgetSaveScope scope) {
    if (scope == _BudgetSaveScope.currentMonth) {
      return [DateTime(widget.currentMonth.year, widget.currentMonth.month)];
    }

    return [
      for (var month = widget.currentMonth.month; month <= 12; month++)
        DateTime(widget.currentMonth.year, month),
    ];
  }

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final budgetSnapshot = await FirebaseFirestore.instance
        .collection("budgets")
        .where("userId", isEqualTo: user.uid)
        .where("month", isEqualTo: widget.currentMonth.month)
        .where("year", isEqualTo: widget.currentMonth.year)
        .get();
    if (!context.mounted) return;

    final settingSnapshot = await FirebaseFirestore.instance
        .collection("budget_settings")
        .where("userId", isEqualTo: user.uid)
        .where("month", isEqualTo: widget.currentMonth.month)
        .where("year", isEqualTo: widget.currentMonth.year)
        .limit(1)
        .get();
    if (!context.mounted) return;

    for (final doc in budgetSnapshot.docs) {
      final data = doc.data();
      final category = data["category"]?.toString();
      final amount = data["amount"];
      if (category == null || amount is! num) continue;

      final type =
          data["type"]?.toString() ??
          (category == totalBudgetCategory ? "total" : "category");

      existingBudgets[category] = _ExistingBudget(
        id: doc.id,
        amount: amount.toDouble(),
        type: type,
      );
      amounts[category] = amount.toDouble();
    }

    if (settingSnapshot.docs.isNotEmpty) {
      final doc = settingSnapshot.docs.first;
      final data = doc.data();
      settingId = doc.id;
      includeUnbudgetedExpenses = data["includeUnbudgetedExpenses"] != false;
    }

    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  Future<void> openAmountDialog({
    required String category,
    required IconData icon,
    required Color color,
  }) async {
    final result = await showDialog<double?>(
      context: context,
      builder: (dialogContext) => _AmountInputDialog(
        category: category,
        icon: icon,
        iconColor: color,
        initialAmount: amounts[category],
      ),
    );
    if (!context.mounted) return;
    if (result == null) return;

    final scope = await chooseSaveScope();
    if (!context.mounted) return;
    if (scope == null) return;

    await saveBudgetAmounts(
      changedAmounts: {category: result <= 0 ? null : result},
      scope: scope,
    );
    if (!context.mounted) return;
    if (!mounted) return;

    setState(() {
      amounts[category] = result <= 0 ? null : result;
    });
  }

  Future<_BudgetSaveScope?> chooseSaveScope() {
    return showDialog<_BudgetSaveScope>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "Vui lòng chọn cách lưu",
            style: TextStyle(color: Colors.black87),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SaveScopeOption(
                title: "Chỉ thay đổi tháng này",
                onTap: () =>
                    Navigator.pop(context, _BudgetSaveScope.currentMonth),
              ),
              const Divider(height: 1),
              _SaveScopeOption(
                title: "Thay đổi tháng này và các tháng sau",
                onTap: () => Navigator.pop(
                  context,
                  _BudgetSaveScope.currentAndFutureMonths,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Bỏ qua",
                style: TextStyle(color: primaryGreen),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> saveBudgetAmounts({
    required Map<String, double?> changedAmounts,
    required _BudgetSaveScope scope,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || isSaving) return;

    setState(() {
      isSaving = true;
    });

    final batch = FirebaseFirestore.instance.batch();
    final budgets = FirebaseFirestore.instance.collection("budgets");
    final settings = FirebaseFirestore.instance.collection("budget_settings");
    final now = FieldValue.serverTimestamp();
    final targetMonths = targetMonthsForScope(scope);
    final changedCategoryNames = changedAmounts.keys.toList();

    for (final monthDate in targetMonths) {
      final budgetSnapshot = await budgets
          .where("userId", isEqualTo: user.uid)
          .where("month", isEqualTo: monthDate.month)
          .where("year", isEqualTo: monthDate.year)
          .get();
      if (!context.mounted) return;

      final existingByCategory = <String, List<QueryDocumentSnapshot>>{};

      for (final doc in budgetSnapshot.docs) {
        final data = doc.data();
        final category = data["category"]?.toString();
        if (category == null) continue;
        existingByCategory.putIfAbsent(category, () => []).add(doc);
      }

      for (final category in changedCategoryNames) {
        final amount = changedAmounts[category] ?? 0;
        final existingDocs = existingByCategory[category] ?? [];

        if (amount <= 0) {
          for (final doc in existingDocs) {
            batch.delete(doc.reference);
          }
          continue;
        }

        final data = {
          "userId": user.uid,
          "category": category,
          "amount": amount,
          "month": monthDate.month,
          "year": monthDate.year,
          "type": category == totalBudgetCategory ? "total" : "category",
          "updatedAt": now,
        };

        if (existingDocs.isEmpty) {
          final doc = budgets.doc();
          batch.set(doc, {...data, "createdAt": now});
        } else {
          batch.update(existingDocs.first.reference, data);
          for (final duplicate in existingDocs.skip(1)) {
            batch.delete(duplicate.reference);
          }
        }
      }

      final settingSnapshot = await settings
          .where("userId", isEqualTo: user.uid)
          .where("month", isEqualTo: monthDate.month)
          .where("year", isEqualTo: monthDate.year)
          .limit(1)
          .get();
      if (!context.mounted) return;

      final settingData = {
        "userId": user.uid,
        "month": monthDate.month,
        "year": monthDate.year,
        "includeUnbudgetedExpenses": includeUnbudgetedExpenses,
        "updatedAt": now,
      };

      if (settingSnapshot.docs.isEmpty) {
        batch.set(settings.doc(), settingData);
      } else {
        batch.update(settingSnapshot.docs.first.reference, settingData);
      }
    }

    await batch.commit();
    if (!context.mounted) return;
    if (!mounted) return;

    setState(() {
      isSaving = false;
    });
  }

  Future<void> saveSettings() async {
    if (isSaving) return;

    final scope = await chooseSaveScope();
    if (!context.mounted) return;
    if (scope == null) return;

    await saveBudgetAmounts(changedAmounts: Map.of(amounts), scope: scope);
    final currentContext = context;
    if (!currentContext.mounted) return;
    final navigator = Navigator.of(currentContext);
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softGreen,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Cài đặt Ngân sách",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.close),
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : saveSettings,
            child: Text(
              isSaving ? "Đang lưu" : "Lưu",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Center(
                  child: Text(
                    DateFormat("MM/yyyy").format(widget.currentMonth),
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SettingTile(
                  icon: Icons.account_balance_wallet,
                  iconColor: primaryGreen,
                  title: totalBudgetCategory,
                  value: displayAmount(amounts[totalBudgetCategory]),
                  onTap: () => openAmountDialog(
                    category: totalBudgetCategory,
                    icon: Icons.account_balance_wallet,
                    color: primaryGreen,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
                  child: Text(
                    "Tổng ngân sách theo hạng mục: ${formatMoney(categoryBudgetTotal)}",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Card(
                  color: Colors.white,
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: lineGreen),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < categories.length; index++)
                        _SettingTile(
                          icon: categories[index].icon,
                          iconColor: categories[index].color,
                          title: categories[index].name,
                          value: displayAmount(amounts[categories[index].name]),
                          showDivider: index != categories.length - 1,
                          onTap: () => openAmountDialog(
                            category: categories[index].name,
                            icon: categories[index].icon,
                            color: categories[index].color,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  "Tính toán tổng ngân sách",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  color: Colors.white,
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: lineGreen),
                  ),
                  child: SwitchListTile(
                    value: includeUnbudgetedExpenses,
                    activeThumbColor: primaryGreen,
                    title: const Text(
                      "Bao gồm chi tiêu chưa đặt ngân sách",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      "Bật: Chi tiêu từ danh mục chưa đặt ngân sách cũng được tính vào tổng.",
                      style: TextStyle(color: Colors.black54),
                    ),
                    secondary: const Icon(Icons.settings, color: primaryGreen),
                    onChanged: (value) {
                      setState(() {
                        includeUnbudgetedExpenses = value;
                      });
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 130),
        child: Text(
          value,
          textAlign: TextAlign.right,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    if (!showDivider) {
      return tile;
    }

    return Column(
      children: [
        tile,
        const Divider(height: 1, color: Colors.black12),
      ],
    );
  }
}

class _SaveScopeOption extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SaveScopeOption({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _BudgetSettingScreenState.primaryGreen,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountInputDialog extends StatefulWidget {
  final String category;
  final IconData icon;
  final Color iconColor;
  final double? initialAmount;

  const _AmountInputDialog({
    required this.category,
    required this.icon,
    required this.iconColor,
    required this.initialAmount,
  });

  @override
  State<_AmountInputDialog> createState() => _AmountInputDialogState();
}

class _AmountInputDialogState extends State<_AmountInputDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.initialAmount == null
          ? ""
          : widget.initialAmount!.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  double parseAmount() {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Row(
        children: [
          Icon(widget.icon, color: widget.iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.category,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: "Số tiền ngân sách",
          suffixText: "đ",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Hủy",
            style: TextStyle(color: _BudgetSettingScreenState.primaryGreen),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 0.0),
          child: const Text("Xóa", style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _BudgetSettingScreenState.primaryGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, parseAmount()),
          child: const Text("OK"),
        ),
      ],
    );
  }
}

class _SettingCategory {
  final String name;
  final IconData icon;
  final Color color;

  const _SettingCategory({
    required this.name,
    required this.icon,
    required this.color,
  });
}

class _ExistingBudget {
  final String id;
  final double amount;
  final String type;

  const _ExistingBudget({
    required this.id,
    required this.amount,
    required this.type,
  });
}
