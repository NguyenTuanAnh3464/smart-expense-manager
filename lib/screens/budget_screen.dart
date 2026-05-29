import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'budget_setting_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  static const Color primaryGreen = Color(0xFF168A36);
  static const Color softGreen = Color(0xFFEAF7EE);
  static const String totalBudgetCategory = "Tổng ngân sách";

  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final NumberFormat moneyFormatter = NumberFormat("#,###", "en_US");

  final List<_BudgetCategory> categories = const [
    _BudgetCategory(
      name: totalBudgetCategory,
      icon: Icons.account_balance_wallet,
      color: primaryGreen,
      isTotal: true,
    ),
    _BudgetCategory(
      name: "Ăn uống",
      icon: Icons.restaurant,
      color: Colors.orange,
    ),
    _BudgetCategory(
      name: "Chi tiêu hằng ngày",
      icon: Icons.local_mall,
      color: primaryGreen,
    ),
    _BudgetCategory(
      name: "Đi lại",
      icon: Icons.directions_bus,
      color: Colors.deepOrange,
    ),
    _BudgetCategory(name: "Quần áo", icon: Icons.checkroom, color: Colors.blue),
    _BudgetCategory(name: "Mỹ phẩm", icon: Icons.brush, color: Colors.pink),
    _BudgetCategory(
      name: "Phí giao lưu",
      icon: Icons.celebration,
      color: Colors.amber,
    ),
    _BudgetCategory(
      name: "Y tế",
      icon: Icons.local_hospital,
      color: Colors.green,
    ),
    _BudgetCategory(
      name: "Giáo dục",
      icon: Icons.school,
      color: Colors.redAccent,
    ),
    _BudgetCategory(
      name: "Tiền điện",
      icon: Icons.flash_on,
      color: Colors.cyan,
    ),
    _BudgetCategory(
      name: "Phí liên lạc",
      icon: Icons.phone_android,
      color: Colors.grey,
    ),
    _BudgetCategory(name: "Tiền nhà", icon: Icons.home, color: Colors.brown),
    _BudgetCategory(name: "Khác", icon: Icons.more_horiz, color: Colors.grey),
  ];

  DateTime get firstDayOfMonth {
    return DateTime(currentMonth.year, currentMonth.month, 1);
  }

  DateTime get lastDayOfMonth {
    return DateTime(currentMonth.year, currentMonth.month + 1, 0);
  }

  String formatMoney(double value) {
    return "${moneyFormatter.format(value)}đ";
  }

  DateTime? parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool isInCurrentMonth(DateTime date) {
    return date.year == currentMonth.year && date.month == currentMonth.month;
  }

  void previousMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    });
  }

  void nextMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    });
  }

  Map<String, _BudgetData> mapBudgets(QuerySnapshot snapshot) {
    final result = <String, _BudgetData>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data["category"]?.toString();
      final amount = data["amount"];

      if (category == null || amount is! num) continue;

      result[category] = _BudgetData(
        id: doc.id,
        amount: amount.toDouble(),
        type:
            data["type"]?.toString() ??
            (category == totalBudgetCategory ? "total" : "category"),
      );
    }

    return result;
  }

  Map<String, double> mapExpenses(QuerySnapshot snapshot) {
    final result = <String, double>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = parseDate(data["date"]);
      if (date == null || !isInCurrentMonth(date)) continue;
      if (data["type"] != "expense") continue;

      final amount = (data["amount"] as num).toDouble();
      final category = data["category"]?.toString() ?? "Khác";

      result[category] = (result[category] ?? 0) + amount;
    }

    return result;
  }

  double totalSpentForBudgetMode({
    required Map<String, double> expenses,
    required Map<String, _BudgetData> budgets,
    required bool includeUnbudgetedExpenses,
  }) {
    if (includeUnbudgetedExpenses) {
      return expenses.values.fold<double>(0, (total, amount) => total + amount);
    }

    return expenses.entries.fold<double>(0, (total, entry) {
      final budget = budgets[entry.key];
      if (budget == null || budget.type != "category") return total;
      return total + entry.value;
    });
  }

  Stream<QuerySnapshot> budgetSettingStream(String userId) {
    return FirebaseFirestore.instance
        .collection("budget_settings")
        .where("userId", isEqualTo: userId)
        .where("month", isEqualTo: currentMonth.month)
        .where("year", isEqualTo: currentMonth.year)
        .limit(1)
        .snapshots();
  }

  Future<void> openBudgetSettings() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BudgetSettingScreen(currentMonth: currentMonth),
      ),
    );
    final currentContext = context;
    if (!currentContext.mounted) return;

    if (saved == true) {
      ScaffoldMessenger.of(
        currentContext,
      ).showSnackBar(const SnackBar(content: Text("Đã lưu cài đặt ngân sách")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Chưa đăng nhập")));
    }

    return Scaffold(
      backgroundColor: softGreen,
      appBar: AppBar(
        title: const Text(
          "Ngân sách",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: openBudgetSettings,
            icon: const Icon(Icons.tune),
            tooltip: "Cài đặt",
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("budgets")
            .where("userId", isEqualTo: user.uid)
            .where("month", isEqualTo: currentMonth.month)
            .where("year", isEqualTo: currentMonth.year)
            .snapshots(),
        builder: (context, budgetSnapshot) {
          if (!budgetSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("transactions")
                .where("userId", isEqualTo: user.uid)
                .snapshots(),
            builder: (context, transactionSnapshot) {
              if (!transactionSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot>(
                stream: budgetSettingStream(user.uid),
                builder: (context, settingSnapshot) {
                  if (!settingSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final settingDocs = settingSnapshot.data!.docs;
                  final includeUnbudgeted = settingDocs.isEmpty
                      ? true
                      : ((settingDocs.first.data()
                                as Map<
                                  String,
                                  dynamic
                                >)["includeUnbudgetedExpenses"] !=
                            false);
                  final budgets = mapBudgets(budgetSnapshot.data!);
                  final expenses = mapExpenses(transactionSnapshot.data!);
                  final totalSpent = totalSpentForBudgetMode(
                    expenses: expenses,
                    budgets: budgets,
                    includeUnbudgetedExpenses: includeUnbudgeted,
                  );
                  final visibleCategories = categories
                      .where((category) => budgets[category.name] != null)
                      .toList();

                  return Column(
                    children: [
                      _MonthHeader(
                        title: DateFormat("MM/yyyy").format(currentMonth),
                        range:
                            "(${DateFormat("dd/MM").format(firstDayOfMonth)} - ${DateFormat("dd/MM").format(lastDayOfMonth)})",
                        onPrevious: previousMonth,
                        onNext: nextMonth,
                      ),
                      if (visibleCategories.isEmpty)
                        Expanded(
                          child: _EmptyBudgetState(
                            onSetupPressed: openBudgetSettings,
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                            itemCount: visibleCategories.length,
                            itemBuilder: (context, index) {
                              final category = visibleCategories[index];
                              final budget = budgets[category.name];
                              final spent = category.isTotal
                                  ? totalSpent
                                  : (expenses[category.name] ?? 0);

                              return _BudgetTile(
                                category: category,
                                budget: budget,
                                spent: spent,
                                formatMoney: formatMoney,
                                onTap: openBudgetSettings,
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final String title;
  final String range;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.title,
    required this.range,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _BudgetScreenState.primaryGreen,
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  range,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final _BudgetCategory category;
  final _BudgetData? budget;
  final double spent;
  final String Function(double value) formatMoney;
  final VoidCallback onTap;

  const _BudgetTile({
    required this.category,
    required this.budget,
    required this.spent,
    required this.formatMoney,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final budgetAmount = budget?.amount;
    final hasBudget = budgetAmount != null;
    final progress = hasBudget ? (spent / budgetAmount).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = hasBudget && spent > budgetAmount;
    final progressColor = isOverBudget
        ? Colors.red
        : _BudgetScreenState.primaryGreen;
    final percentText = hasBudget
        ? "${(spent / budgetAmount * 100).toStringAsFixed(0)}%"
        : "-";
    final remaining = hasBudget ? budgetAmount - spent : 0.0;

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(category.icon, color: category.color, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (hasBudget)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: isOverBudget ? "Vượt: " : "Còn lại: ",
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: formatMoney(remaining.abs()),
                                style: TextStyle(
                                  color: isOverBudget
                                      ? Colors.red
                                      : Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOverBudget ? "Vượt ngân sách" : percentText,
                          style: TextStyle(
                            color: isOverBudget ? Colors.red : Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Colors.black38),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  color: progressColor,
                  backgroundColor: _BudgetScreenState.softGreen,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hasBudget
                          ? "Ngân sách: ${formatMoney(budgetAmount)}"
                          : "Ngân sách: Chưa đặt",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Chi tiêu: ${formatMoney(spent)}",
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isOverBudget ? Colors.red : Colors.black54,
                        fontSize: 13,
                        fontWeight: isOverBudget
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBudgetState extends StatelessWidget {
  final VoidCallback onSetupPressed;

  const _EmptyBudgetState({required this.onSetupPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              color: _BudgetScreenState.primaryGreen,
              size: 56,
            ),
            const SizedBox(height: 14),
            const Text(
              "Bạn chưa thiết lập ngân sách cho tháng này",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Các danh mục chưa đặt sẽ chỉ xuất hiện trong phần cài đặt.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onSetupPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _BudgetScreenState.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Thiết lập ngân sách",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCategory {
  final String name;
  final IconData icon;
  final Color color;
  final bool isTotal;

  const _BudgetCategory({
    required this.name,
    required this.icon,
    required this.color,
    this.isTotal = false,
  });
}

class _BudgetData {
  final String id;
  final double amount;
  final String type;

  const _BudgetData({
    required this.id,
    required this.amount,
    required this.type,
  });
}
