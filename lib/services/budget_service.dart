import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import 'notification_service.dart';

class BudgetService {
  BudgetService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _notificationService = notificationService ?? NotificationService.instance;

  static const String totalBudgetCategory = "Tổng ngân sách";
  static const double lowRemainingRatio = 0.1;

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;
  final NumberFormat _moneyFormatter = NumberFormat("#,###", "en_US");

  static Future<void> checkBudgetAlert(
    String userId,
    DateTime transactionDate, {
    String? category,
  }) {
    return BudgetService().checkBudgetAlerts(
      userId: userId,
      date: transactionDate,
      category: category,
    );
  }

  Future<void> checkBudgetAlerts({
    required String userId,
    required DateTime date,
    String? category,
  }) async {
    final monthDate = DateTime(date.year, date.month);
    final budgets = await _loadBudgets(userId, monthDate);
    if (budgets.isEmpty) return;

    final includeUnbudgeted = await _loadIncludeUnbudgeted(userId, monthDate);
    final transactions = await _loadMonthTransactions(userId, monthDate);
    final expenses = _mapExpenses(transactions, monthDate);
    final savingTransfers = _mapSavingTransfers(transactions, monthDate);
    final totalSavingTransfers = savingTransfers.values.fold<double>(
      0,
      (total, amount) => total + amount,
    );
    final totalSpent = _totalSpentForBudgetMode(
      expenses: expenses,
      budgets: budgets,
      includeUnbudgetedExpenses: includeUnbudgeted,
    );
    final totalUsed = totalSpent + totalSavingTransfers;

    final checks = <_BudgetUsageCheck>[];
    final totalBudget = budgets[totalBudgetCategory];
    if (totalBudget != null && totalBudget.amount > 0) {
      checks.add(
        _BudgetUsageCheck(
          key: "total",
          titleName: "Tổng ngân sách",
          budgetAmount: totalBudget.amount,
          usedAmount: totalUsed,
          isTotal: true,
        ),
      );
    }

    final normalizedCategory = category?.trim();
    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      final categoryBudget = budgets[normalizedCategory];
      if (categoryBudget != null &&
          categoryBudget.type != "total" &&
          categoryBudget.amount > 0) {
        checks.add(
          _BudgetUsageCheck(
            key: "category:$normalizedCategory",
            titleName: normalizedCategory,
            budgetAmount: categoryBudget.amount,
            usedAmount:
                (expenses[normalizedCategory] ?? 0) +
                (savingTransfers[normalizedCategory] ?? 0),
          ),
        );
      }
    }

    for (final check in checks) {
      await _sendOrResetAlert(
        userId: userId,
        year: monthDate.year,
        month: monthDate.month,
        check: check,
      );
    }
  }

  Future<Map<String, _BudgetData>> _loadBudgets(
    String userId,
    DateTime monthDate,
  ) async {
    final snapshot = await _firestore
        .collection("budgets")
        .where("userId", isEqualTo: userId)
        .where("month", isEqualTo: monthDate.month)
        .where("year", isEqualTo: monthDate.year)
        .get();

    final result = <String, _BudgetData>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final category = data["category"]?.toString().trim();
      final amount = TransactionModel.parseAmount(data["amount"]);
      if (category == null || category.isEmpty || amount <= 0) continue;
      result[category] = _BudgetData(
        amount: amount,
        type:
            data["type"]?.toString() ??
            (category == totalBudgetCategory ? "total" : "category"),
      );
    }
    return result;
  }

  Future<List<_BudgetTransaction>> _loadMonthTransactions(
    String userId,
    DateTime monthDate,
  ) async {
    final snapshot = await _firestore
        .collection("transactions")
        .where("userId", isEqualTo: userId)
        .get();
    return snapshot.docs.map((doc) {
      return _BudgetTransaction(
        transaction: TransactionModel.fromFirestore(doc),
        data: doc.data(),
      );
    }).toList();
  }

  Future<bool> _loadIncludeUnbudgeted(
    String userId,
    DateTime monthDate,
  ) async {
    final snapshot = await _firestore
        .collection("budget_settings")
        .where("userId", isEqualTo: userId)
        .where("month", isEqualTo: monthDate.month)
        .where("year", isEqualTo: monthDate.year)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return true;
    return snapshot.docs.first.data()["includeUnbudgetedExpenses"] != false;
  }

  Map<String, double> _mapExpenses(
    List<_BudgetTransaction> transactions,
    DateTime monthDate,
  ) {
    final result = <String, double>{};
    for (final item in transactions) {
      final transaction = item.transaction;
      if (!transaction.isExpense ||
          transaction.date.year != monthDate.year ||
          transaction.date.month != monthDate.month) {
        continue;
      }
      result[transaction.category] =
          (result[transaction.category] ?? 0) + transaction.amount;
    }
    return result;
  }

  Map<String, double> _mapSavingTransfers(
    List<_BudgetTransaction> transactions,
    DateTime monthDate,
  ) {
    final result = <String, double>{};
    for (final item in transactions) {
      final transaction = item.transaction;
      if (!transaction.isSaving) continue;
      if (item.data["sourceBudgetMonth"] != monthDate.month ||
          item.data["sourceBudgetYear"] != monthDate.year) {
        continue;
      }

      final sourceCategory = item.data["sourceBudgetCategory"]
          ?.toString()
          .trim();
      if (sourceCategory == null || sourceCategory.isEmpty) continue;
      result[sourceCategory] = (result[sourceCategory] ?? 0) + transaction.amount;
    }

    return result;
  }

  double _totalSpentForBudgetMode({
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

  Future<void> _sendOrResetAlert({
    required String userId,
    required int year,
    required int month,
    required _BudgetUsageCheck check,
  }) async {
    final progress = check.budgetAmount <= 0
        ? 0.0
        : check.usedAmount / check.budgetAmount;
    final remainingAmount = check.budgetAmount - check.usedAmount;
    final lowRemainingThreshold = check.budgetAmount * lowRemainingRatio;

    if (progress < 0.8) {
      await _notificationService.resetBudgetWarning(
        userId: userId,
        year: year,
        month: month,
        keyPrefix: check.key,
      );
      return;
    }

    final alert = progress >= 1
        ? _overBudgetAlert(check)
        : remainingAmount <= lowRemainingThreshold
            ? (
                key: "${check.key}:low",
                title: "Ngân sách còn lại thấp",
                body:
                    "Ngân sách ${check.titleName} chỉ còn ${_formatMoney(remainingAmount.clamp(0, double.infinity).toDouble())}.",
              )
            : (
                key: "${check.key}:80",
                title: "Bạn đã dùng 80% ngân sách ${check.titleName}",
                body:
                    "Bạn đã dùng ${(progress * 100).toStringAsFixed(0)}% ngân sách ${check.titleName}.",
              );

    await _notificationService.showBudgetWarning(
      userId: userId,
      year: year,
      month: month,
      key: alert.key,
      title: alert.title,
      body: alert.body,
    );
  }

  String _formatMoney(double value) {
    return "${_moneyFormatter.format(value)}đ";
  }

  ({String key, String title, String body}) _overBudgetAlert(
    _BudgetUsageCheck check,
  ) {
    if (check.isTotal) {
      return (
        key: "${check.key}:100",
        title: "Bạn đã vượt Tổng ngân sách tháng này",
        body:
            "Bạn đã vượt Tổng ngân sách tháng này ${_formatMoney(check.usedAmount - check.budgetAmount)}.",
      );
    }

    return (
      key: "${check.key}:100",
      title: "Bạn đã vượt ngân sách ${check.titleName}",
      body:
          "Bạn đã vượt ngân sách ${check.titleName} ${_formatMoney(check.usedAmount - check.budgetAmount)}.",
    );
  }
}

class _BudgetData {
  final double amount;
  final String type;

  const _BudgetData({required this.amount, required this.type});
}

class _BudgetTransaction {
  final TransactionModel transaction;
  final Map<String, dynamic> data;

  const _BudgetTransaction({required this.transaction, required this.data});
}

class _BudgetUsageCheck {
  final String key;
  final String titleName;
  final double budgetAmount;
  final double usedAmount;
  final bool isTotal;

  const _BudgetUsageCheck({
    required this.key,
    required this.titleName,
    required this.budgetAmount,
    required this.usedAmount,
    this.isTotal = false,
  });
}
