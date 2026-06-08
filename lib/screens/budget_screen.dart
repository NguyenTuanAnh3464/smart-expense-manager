import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/account_model.dart';
import '../models/saving_goal_model.dart';
import '../models/transaction_model.dart';
import '../services/account_service.dart';
import '../services/saving_goal_service.dart';
import '../widgets/category_icon_helper.dart';
import 'budget_setting_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  static const Color primaryGreen = Color(0xFF168A36);
  static const String totalBudgetCategory = "Tổng ngân sách";
  final SavingGoalService savingGoalService = SavingGoalService();
  final AccountService accountService = AccountService();

  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final NumberFormat moneyFormatter = NumberFormat("#,###", "en_US");

  static const List<_BudgetCategory> defaultCategories = [
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

  Stream<QuerySnapshot> categoryStream(String userId) {
    return FirebaseFirestore.instance
        .collection("categories")
        .where("userId", isEqualTo: userId)
        .where("type", isEqualTo: "expense")
        .snapshots();
  }

  List<_BudgetCategory> mapCategories(QuerySnapshot snapshot) {
    final merged = <_BudgetCategory>[];
    final names = <String>{};
    for (final category in defaultCategories) {
      if (names.add(category.name)) merged.add(category);
    }
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data["name"]?.toString().trim();
      if (name == null || name.isEmpty || !names.add(name)) continue;
      merged.add(
        _BudgetCategory(
          name: name,
          icon: getCategoryIcon(data["iconName"]?.toString()),
          color: getCategoryColor(data["color"], fallback: primaryGreen),
        ),
      );
    }
    return merged;
  }

  DateTime get firstDayOfMonth {
    return DateTime(currentMonth.year, currentMonth.month, 1);
  }

  DateTime get lastDayOfMonth {
    return DateTime(currentMonth.year, currentMonth.month + 1, 0);
  }

  String formatMoney(double value) {
    return "${moneyFormatter.format(value)}đ";
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

      if (category == null || amount is! num || amount <= 0) continue;

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
      final transaction = TransactionModel.fromMap(data, id: doc.id);
      if (!isInCurrentMonth(transaction.date) || !transaction.isExpense) {
        continue;
      }

      result[transaction.category] =
          (result[transaction.category] ?? 0) + transaction.amount;
    }

    return result;
  }

  Map<String, double> mapSavingTransfers(QuerySnapshot snapshot) {
    final result = <String, double>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (TransactionModel.normalizeType(data["type"]?.toString()) !=
          "saving") {
        continue;
      }
      if (data["sourceBudgetMonth"] != currentMonth.month ||
          data["sourceBudgetYear"] != currentMonth.year) {
        continue;
      }

      final category = data["sourceBudgetCategory"]?.toString();
      if (category == null || category.isEmpty) continue;
      final amount = TransactionModel.parseAmount(data["amount"]);
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

  List<_BudgetWarning> buildWarnings({
    required Map<String, double> expenses,
    required Map<String, double> savingTransfers,
    required Map<String, _BudgetData> budgets,
    required double totalSpent,
  }) {
    final warnings = <_BudgetWarning>[];
    final totalBudget = budgets[totalBudgetCategory];
    if (totalBudget != null &&
        totalBudget.amount > 0 &&
        totalSpent > totalBudget.amount) {
      warnings.add(
        _BudgetWarning(
          key: "total",
          title: "Vượt tổng ngân sách",
          message:
              "Chi tiêu tháng này vượt ${formatMoney(totalSpent - totalBudget.amount)} so với tổng ngân sách.",
        ),
      );
    }

    final checkedCategories = <String>{
      ...expenses.keys,
      ...savingTransfers.keys,
    };
    for (final category in checkedCategories) {
      final budget = budgets[category];
      if (budget == null || budget.type != "category" || budget.amount <= 0) {
        continue;
      }
      final usedAmount =
          (expenses[category] ?? 0) + (savingTransfers[category] ?? 0);
      if (usedAmount > budget.amount) {
        warnings.add(
          _BudgetWarning(
            key: "category:$category",
            title: "Vượt ngân sách $category",
            message:
                "Đã vượt ${formatMoney(usedAmount - budget.amount)} trong danh mục $category.",
          ),
        );
      }
    }

    return warnings;
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
    if (!mounted) return;

    if (saved == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã lưu cài đặt ngân sách")));
    }
  }

  Future<void> openTransferToGoalSheet({
    required _BudgetCategory category,
    _BudgetData? budget,
    required double remainingAmount,
  }) async {
    try {
      final goals = await savingGoalService.getGoalsOnce();
      final accounts = await accountService.getAccountsOnce();
      if (!mounted) return;

      final activeGoals = goals
          .where((goal) => goal.targetAmount > goal.currentAmount)
          .toList();
      if (activeGoals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Chưa có mục tiêu tiết kiệm cần góp")),
        );
        return;
      }

      final request = await showModalBottomSheet<_SavingTransferRequest>(
        context: context,
        isScrollControlled: true,
        backgroundColor:
            Theme.of(context).bottomSheetTheme.backgroundColor ??
            Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (_) => _SavingTransferSheet(
          goals: activeGoals,
          accounts: accounts,
          remainingBudget: remainingAmount,
          formatMoney: formatMoney,
        ),
      );
      if (!mounted || request == null) return;

      await savingGoalService.transferToGoal(
        goalId: request.goalId,
        accountId: request.accountId,
        amount: request.amount,
        maxBudgetAmount: remainingAmount,
        budgetId: budget?.id,
        sourceBudgetCategory: category.name,
        budgetMonth: currentMonth.month,
        budgetYear: currentMonth.year,
        note: "Chuyển từ ngân sách ${category.name}",
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã chuyển tiền vào mục tiêu tiết kiệm")),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể chuyển tiền: $error")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Chưa đăng nhập")));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 40,
        title: const Text(
          "Ngân sách",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
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
                  return StreamBuilder<QuerySnapshot>(
                    stream: categoryStream(user.uid),
                    builder: (context, categorySnapshot) {
                      if (!categorySnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final budgets = mapBudgets(budgetSnapshot.data!);
                      final expenses = mapExpenses(transactionSnapshot.data!);
                      final savingTransfers = mapSavingTransfers(
                        transactionSnapshot.data!,
                      );
                      final totalSavingTransfers = savingTransfers.values
                          .fold<double>(0, (total, amount) => total + amount);
                      final totalSpent = totalSpentForBudgetMode(
                        expenses: expenses,
                        budgets: budgets,
                        includeUnbudgetedExpenses: includeUnbudgeted,
                      );
                      final totalUsed = totalSpent + totalSavingTransfers;
                      final warnings = buildWarnings(
                        expenses: expenses,
                        savingTransfers: savingTransfers,
                        budgets: budgets,
                        totalSpent: totalUsed,
                      );
                      final categories = mapCategories(categorySnapshot.data!);
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
                          if (warnings.isNotEmpty)
                            _BudgetWarningPanel(warnings: warnings),
                          if (visibleCategories.isEmpty)
                            Expanded(
                              child: _EmptyBudgetState(
                                onSetupPressed: openBudgetSettings,
                              ),
                            )
                          else
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  20,
                                ),
                                itemCount: visibleCategories.length,
                                itemBuilder: (context, index) {
                                  final category = visibleCategories[index];
                                  final budget = budgets[category.name];
                                  final spent = category.isTotal
                                      ? totalSpent
                                      : (expenses[category.name] ?? 0);
                                  final transferredToSaving = category.isTotal
                                      ? totalSavingTransfers
                                      : (savingTransfers[category.name] ?? 0);

                                  return _BudgetTile(
                                    category: category,
                                    budget: budget,
                                    spent: spent,
                                    transferredToSaving: transferredToSaving,
                                    formatMoney: formatMoney,
                                    onTap: openBudgetSettings,
                                    onTransferToGoal: (remaining) {
                                      openTransferToGoalSheet(
                                        category: category,
                                        budget: budget,
                                        remainingAmount: remaining,
                                      );
                                    },
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
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  range,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            icon: const Icon(Icons.chevron_right, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BudgetWarningPanel extends StatelessWidget {
  final List<_BudgetWarning> warnings;

  const _BudgetWarningPanel({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Cảnh báo chi tiêu",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final warning in warnings.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                warning.message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
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
  final double transferredToSaving;
  final String Function(double value) formatMoney;
  final VoidCallback onTap;
  final ValueChanged<double> onTransferToGoal;

  const _BudgetTile({
    required this.category,
    required this.budget,
    required this.spent,
    required this.transferredToSaving,
    required this.formatMoney,
    required this.onTap,
    required this.onTransferToGoal,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final budgetAmount = budget?.amount;
    final hasBudget = budgetAmount != null && budgetAmount > 0;
    final usedAmount = spent + transferredToSaving;
    final progress = hasBudget
        ? (usedAmount / budgetAmount).clamp(0.0, 1.0)
        : 0.0;
    final isOverBudget = hasBudget && usedAmount > budgetAmount;
    final progressColor = isOverBudget
        ? Colors.red
        : _BudgetScreenState.primaryGreen;
    final percentText = hasBudget
        ? "${(usedAmount / budgetAmount * 100).toStringAsFixed(0)}%"
        : "-";
    final remaining = hasBudget ? budgetAmount - usedAmount : 0.0;
    final transferableAmount = remaining.clamp(0.0, double.infinity).toDouble();

    return Card(
      color: theme.cardColor,
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
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
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
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.68,
                              ),
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: formatMoney(remaining.abs()),
                                style: TextStyle(
                                  color: isOverBudget
                                      ? Colors.red
                                      : theme.colorScheme.onSurface,
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
                            color: isOverBudget
                                ? Colors.red
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.68,
                                  ),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 9,
                  value: progress,
                  color: progressColor,
                  backgroundColor: theme.dividerColor,
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
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Đã dùng: ${formatMoney(usedAmount)}",
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isOverBudget
                            ? Colors.red
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.68,
                              ),
                        fontSize: 13,
                        fontWeight: isOverBudget
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              if (transferableAmount > 0) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => onTransferToGoal(transferableAmount),
                    icon: const Icon(Icons.savings_outlined, size: 18),
                    label: const Text("Chuyển vào mục tiêu"),
                    style: TextButton.styleFrom(
                      foregroundColor: _BudgetScreenState.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SavingTransferRequest {
  final String goalId;
  final String? accountId;
  final double amount;

  const _SavingTransferRequest({
    required this.goalId,
    required this.accountId,
    required this.amount,
  });
}

class _SavingTransferSheet extends StatefulWidget {
  final List<SavingGoalModel> goals;
  final List<AccountModel> accounts;
  final double remainingBudget;
  final String Function(double value) formatMoney;

  const _SavingTransferSheet({
    required this.goals,
    required this.accounts,
    required this.remainingBudget,
    required this.formatMoney,
  });

  @override
  State<_SavingTransferSheet> createState() => _SavingTransferSheetState();
}

class _SavingTransferSheetState extends State<_SavingTransferSheet> {
  late final TextEditingController amountController;
  String? selectedGoalId;
  String? selectedAccountId;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController();
    final goalsWithId = widget.goals.where((goal) => goal.id != null).toList();
    selectedGoalId = goalsWithId.isEmpty ? null : goalsWithId.first.id;
    if (widget.accounts.isNotEmpty) {
      final defaultAccount = widget.accounts.where((account) => account.isDefault);
      selectedAccountId = defaultAccount.isNotEmpty
          ? defaultAccount.first.id
          : widget.accounts.first.id;
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  SavingGoalModel? get selectedGoal {
    final id = selectedGoalId;
    if (id == null) return null;
    for (final goal in widget.goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  AccountModel? get selectedAccount {
    final id = selectedAccountId;
    if (id == null) return null;
    for (final account in widget.accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  double get maxTransferAmount {
    final goal = selectedGoal;
    if (goal == null) return 0;
    final missingGoalAmount = goal.targetAmount - goal.currentAmount;
    final accountBalance = selectedAccount?.balance ?? double.infinity;
    final maxAmount = [
      widget.remainingBudget,
      missingGoalAmount,
      accountBalance,
    ].reduce((a, b) => a < b ? a : b);
    return maxAmount.isFinite
        ? maxAmount.clamp(0.0, double.infinity).toDouble()
        : 0;
  }

  void save() {
    final amount =
        double.tryParse(amountController.text.replaceAll(",", "").trim()) ?? 0;
    final goalId = selectedGoalId;
    if (goalId == null || goalId.isEmpty) {
      showError("Vui lòng chọn mục tiêu tiết kiệm");
      return;
    }
    if (widget.accounts.isNotEmpty &&
        (selectedAccountId == null || selectedAccountId!.isEmpty)) {
      showError("Vui lòng chọn tài khoản tiền");
      return;
    }
    if (amount <= 0) {
      showError("Số tiền chuyển phải lớn hơn 0");
      return;
    }
    if (amount > maxTransferAmount) {
      showError(
        "Số tiền chuyển tối đa là ${widget.formatMoney(maxTransferAmount)}",
      );
      return;
    }
    if (amount > maxTransferAmount) {
      showError("Số tiền chuyển vượt quá mức tối đa");
      return;
    }

    Navigator.pop(
      context,
      _SavingTransferRequest(
        goalId: goalId,
        accountId: selectedAccountId,
        amount: amount,
      ),
    );
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final goalsWithId = widget.goals.where((goal) => goal.id != null).toList();
    final maxAmount = maxTransferAmount;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "Chuyển vào mục tiêu",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: selectedGoalId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "Mục tiêu tiết kiệm",
                  border: OutlineInputBorder(),
                ),
                items: goalsWithId
                    .map(
                      (goal) => DropdownMenuItem(
                        value: goal.id,
                        child: Text(
                          "${goal.title} - còn ${widget.formatMoney(goal.targetAmount - goal.currentAmount)}",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedGoalId = value;
                  });
                },
              ),
              if (widget.accounts.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: "Tài khoản tiền",
                    border: OutlineInputBorder(),
                  ),
                  items: widget.accounts
                      .where((account) => account.id != null)
                      .map(
                        (account) => DropdownMenuItem(
                          value: account.id,
                          child: Text(
                            "${account.name} - ${widget.formatMoney(account.balance)}",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedAccountId = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: "Số tiền muốn chuyển",
                  suffixText: "đ",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Tối đa có thể chuyển: ${widget.formatMoney(maxAmount)}",
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Hủy"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: maxAmount > 0 ? save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _BudgetScreenState.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Lưu"),
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
            Text(
              "Bạn chưa thiết lập ngân sách cho tháng này",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Các danh mục chưa đặt sẽ chỉ xuất hiện trong phần cài đặt.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.68),
              ),
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

class _BudgetWarning {
  final String key;
  final String title;
  final String message;

  const _BudgetWarning({
    required this.key,
    required this.title,
    required this.message,
  });
}
