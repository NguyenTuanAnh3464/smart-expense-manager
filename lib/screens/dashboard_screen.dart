import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../services/account_service.dart';
import '../services/transaction_service.dart';
import '../widgets/app_ui.dart';
import 'add_transaction_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TransactionService transactionService = TransactionService();
  final AccountService accountService = AccountService();
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    () async {
      try {
        await accountService.ensureDefaultAccount();
      } catch (_) {}
    }();
  }

  void previousMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    });
  }

  void nextMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
    });
  }

  Future<void> openAddTransaction(String type) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionScreen(type: type)),
    );
    if (!mounted || result == null) return;

    try {
      await transactionService.addTransaction(result);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã thêm giao dịch")));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể thêm giao dịch: $error")),
      );
    }
  }

  bool isInSelectedMonth(TransactionModel item) {
    return item.date.year == selectedMonth.year &&
        item.date.month == selectedMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Chưa đăng nhập")));
    }

    return Scaffold(
      backgroundColor: AppUi.pageBackground(context),
      appBar: AppBar(
        title: const Text(
          "Tổng quan",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppUi.primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () => openAddTransaction("expense"),
        tooltip: "Thêm giao dịch",
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<AccountModel>>(
        stream: accountService.getAccountsStream(),
        builder: (context, accountSnapshot) {
          if (accountSnapshot.hasError) {
            return _ErrorState(message: accountSnapshot.error.toString());
          }

          if (!accountSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final accountBalance = accountSnapshot.data!.fold<double>(
            0,
            (total, account) => total + account.balance,
          );

          return StreamBuilder<List<TransactionModel>>(
            stream: transactionService.getTransactionsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorState(message: snapshot.error.toString());
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final transactions = snapshot.data!;
              final monthTransactions = transactions
                  .where(isInSelectedMonth)
                  .toList();
              final totalIncome = monthTransactions
                  .where((item) => item.isIncome)
                  .fold<double>(0, (total, item) => total + item.amount);
              final totalExpense = monthTransactions
                  .where((item) => item.isExpense)
                  .fold<double>(0, (total, item) => total + item.amount);
              final monthBalance = totalIncome - totalExpense;
              final expenseByCategory = _expenseByCategory(monthTransactions);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _BalanceBanner(
                    email: user.email ?? "No Email",
                    accountBalance: accountBalance,
                    monthBalance: monthBalance,
                    monthLabel: DateFormat("MM/yyyy").format(selectedMonth),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SummaryMetricCard(
                          title: "Tổng thu",
                          amount: AppUi.money(totalIncome),
                          icon: Icons.trending_up,
                          color: AppUi.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryMetricCard(
                          title: "Tổng chi",
                          amount: AppUi.money(totalExpense),
                          icon: Icons.trending_down,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MonthNavigator(
                    title: DateFormat("MM/yyyy").format(selectedMonth),
                    onPrevious: previousMonth,
                    onNext: nextMonth,
                  ),
                  const SizedBox(height: 14),
                  _SpendingChartCard(data: expenseByCategory),
                  const SizedBox(height: 14),
                  _InsightCard(
                    totalExpense: totalExpense,
                    totalIncome: totalIncome,
                    hasData: monthTransactions.isNotEmpty,
                  ),
                  const SizedBox(height: 18),
                  AppSectionTitle(
                    title: "Giao dịch gần đây",
                    trailing: TextButton(
                      onPressed: () => openAddTransaction("income"),
                      child: const Text("Thêm thu"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (transactions.isEmpty)
                    const _EmptyTransactionsState()
                  else
                    ...transactions
                        .take(5)
                        .map((item) => _TransactionTile(item: item)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, double> _expenseByCategory(List<TransactionModel> transactions) {
    final result = <String, double>{};
    for (final item in transactions.where((item) => item.isExpense)) {
      result[item.category] = (result[item.category] ?? 0) + item.amount;
    }
    return result;
  }
}

class _BalanceBanner extends StatelessWidget {
  final String email;
  final double accountBalance;
  final double monthBalance;
  final String monthLabel;

  const _BalanceBanner({
    required this.email,
    required this.accountBalance,
    required this.monthBalance,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppUi.lightGreen, AppUi.primaryGreen, AppUi.darkGreen],
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
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Người dùng • $monthLabel",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Tổng số dư tài khoản",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  AppUi.money(accountBalance),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Thu chi tháng: ${AppUi.money(monthBalance)}",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  final String title;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthNavigator({
    required this.title,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            color: AppUi.primaryGreen,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppUi.primaryText(context),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            color: AppUi.primaryGreen,
          ),
        ],
      ),
    );
  }
}

class _SpendingChartCard extends StatelessWidget {
  final Map<String, double> data;

  const _SpendingChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, item) => sum + item.value);

    return AppPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionTitle(title: "Chi tiêu theo danh mục"),
          const SizedBox(height: 14),
          SizedBox(
            height: 210,
            child: entries.isEmpty
                ? const Center(child: Text("Chưa có dữ liệu chi tiêu"))
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 58,
                          startDegreeOffset: -90,
                          sections: entries.asMap().entries.map((entry) {
                            return PieChartSectionData(
                              value: entry.value.value,
                              color: _chartColor(entry.key),
                              radius: 58,
                              title: "",
                            );
                          }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Tổng chi",
                            style: TextStyle(
                              color: AppUi.secondaryText(context),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 120,
                            child: Text(
                              AppUi.money(total),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          for (final entry in entries.take(4).toList().asMap().entries)
            _CategoryLegendRow(
              name: entry.value.key,
              amount: entry.value.value,
              percent: total == 0 ? 0 : entry.value.value / total * 100,
              color: _chartColor(entry.key),
            ),
        ],
      ),
    );
  }

  Color _chartColor(int index) {
    const colors = [
      Colors.redAccent,
      Colors.orange,
      Colors.cyan,
      Colors.amber,
      AppUi.primaryGreen,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }
}

class _CategoryLegendRow extends StatelessWidget {
  final String name;
  final double amount;
  final double percent;
  final Color color;

  const _CategoryLegendRow({
    required this.name,
    required this.amount,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppUi.primaryText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${percent.toStringAsFixed(1)}%",
            style: TextStyle(color: AppUi.secondaryText(context), fontSize: 12),
          ),
          const SizedBox(width: 10),
          Text(
            AppUi.money(amount),
            style: TextStyle(
              color: AppUi.primaryText(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final double totalExpense;
  final double totalIncome;
  final bool hasData;

  const _InsightCard({
    required this.totalExpense,
    required this.totalIncome,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    final percent = totalIncome == 0 ? 0 : totalExpense / totalIncome * 100;
    final message = !hasData
        ? "Chưa có giao dịch trong tháng này."
        : percent > 60
        ? "Chi tiêu đang chiếm ${percent.toStringAsFixed(0)}% thu nhập tháng này."
        : "Dòng tiền tháng này đang trong vùng cân bằng.";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD7A0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.lightbulb_outline, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Gợi ý chi tiêu",
                  style: TextStyle(
                    color: AppUi.primaryText(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(color: AppUi.secondaryText(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel item;

  const _TransactionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = item.isIncome ? AppUi.primaryGreen : Colors.red;

    return AppPanel(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _colorForCategory(
              item.category,
              item.type,
            ).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _iconForCategory(item.category, item.type),
            color: _colorForCategory(item.category, item.type),
          ),
        ),
        title: Text(
          item.category,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppUi.primaryText(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          "${DateFormat("dd/MM/yyyy").format(item.date)}  ${item.note}",
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppUi.secondaryText(context)),
        ),
        trailing: Text(
          "${item.isIncome ? "+" : "-"}${AppUi.money(item.amount)}",
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  IconData _iconForCategory(String category, String type) {
    if (TransactionModel.normalizeType(type) == "income") {
      return Icons.account_balance_wallet;
    }
    switch (category) {
      case "Ăn uống":
        return Icons.restaurant;
      case "Đi lại":
        return Icons.directions_bus;
      case "Tiền nhà":
        return Icons.home;
      case "Giáo dục":
        return Icons.school;
      default:
        return Icons.receipt_long;
    }
  }

  Color _colorForCategory(String category, String type) {
    if (TransactionModel.normalizeType(type) == "income") {
      return AppUi.primaryGreen;
    }
    switch (category) {
      case "Ăn uống":
        return Colors.orange;
      case "Đi lại":
        return Colors.deepOrange;
      case "Tiền nhà":
        return Colors.brown;
      case "Giáo dục":
        return Colors.blue;
      default:
        return Colors.redAccent;
    }
  }
}

class _EmptyTransactionsState extends StatelessWidget {
  const _EmptyTransactionsState();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: AppUi.primaryGreen,
            size: 44,
          ),
          const SizedBox(height: 10),
          Text(
            "Chưa có giao dịch nào",
            style: TextStyle(
              color: AppUi.primaryText(context),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Nhấn nút + để thêm giao dịch đầu tiên.",
            textAlign: TextAlign.center,
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
          "Không thể tải dữ liệu: $message",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
