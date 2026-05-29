import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'add_transaction_screen.dart';

enum ReportPeriod { month, year }

enum ReportType { expense, income }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const Color primaryGreen = Color(0xFF168A36);
  static const Color softGreen = Color(0xFFEAF7EE);
  static const Color lineGreen = Color(0xFFCDE8D4);

  ReportPeriod selectedPeriod = ReportPeriod.month;
  ReportType selectedType = ReportType.expense;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int selectedYear = DateTime.now().year;

  final NumberFormat moneyFormatter = NumberFormat("#,###", "en_US");

  String formatMoney(double value) {
    return "${moneyFormatter.format(value)}đ";
  }

  DateTime get startDate {
    if (selectedPeriod == ReportPeriod.month) {
      return DateTime(selectedMonth.year, selectedMonth.month, 1);
    }
    return DateTime(selectedYear, 1, 1);
  }

  DateTime get endDate {
    if (selectedPeriod == ReportPeriod.month) {
      return DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    }
    return DateTime(selectedYear, 12, 31);
  }

  String get periodTitle {
    if (selectedPeriod == ReportPeriod.month) {
      return DateFormat("MM/yyyy").format(selectedMonth);
    }
    return selectedYear.toString();
  }

  String get periodRange {
    return "(${DateFormat("dd/MM").format(startDate)} - ${DateFormat("dd/MM").format(endDate)})";
  }

  void previousPeriod() {
    setState(() {
      if (selectedPeriod == ReportPeriod.month) {
        selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
      } else {
        selectedYear--;
      }
    });
  }

  void nextPeriod() {
    setState(() {
      if (selectedPeriod == ReportPeriod.month) {
        selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
      } else {
        selectedYear++;
      }
    });
  }

  DateTime? parseDate(dynamic rawDate) {
    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is DateTime) return rawDate;
    return null;
  }

  bool isInSelectedPeriod(DateTime date) {
    return !date.isBefore(startDate) &&
        date.isBefore(endDate.add(const Duration(days: 1)));
  }

  List<Map<String, dynamic>> normalizeTransactions(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final date = parseDate(data["date"]);
          if (date == null) return null;

          return {...data, "id": doc.id, "date": date};
        })
        .whereType<Map<String, dynamic>>()
        .where((item) => isInSelectedPeriod(item["date"] as DateTime))
        .toList();
  }

  Map<String, _CategoryReport> buildCategoryReports(
    List<Map<String, dynamic>> transactions,
    String type,
  ) {
    final reports = <String, _CategoryReport>{};

    for (final transaction in transactions) {
      if (transaction["type"] != type) continue;

      final category = transaction["category"]?.toString() ?? "Khác";
      final amount = (transaction["amount"] as num).toDouble();
      final current = reports[category];

      if (current == null) {
        reports[category] = _CategoryReport(
          name: category,
          amount: amount,
          transactions: [transaction],
        );
      } else {
        current.amount += amount;
        current.transactions.add(transaction);
      }
    }

    final sorted = reports.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));

    return Map.fromEntries(sorted);
  }

  Future<void> editTransaction(Map<String, dynamic> transaction) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          type: transaction["type"],
          transaction: transaction,
        ),
      ),
    );
    if (!context.mounted) return;

    if (result == null) return;

    await FirebaseFirestore.instance
        .collection("transactions")
        .doc(transaction["id"])
        .update({...result, "userId": user.uid});
    if (!context.mounted) return;
  }

  void showCategoryDetails(_CategoryReport report) {
    final transactions = [...report.transactions];
    transactions.sort((a, b) {
      final dateA = a["date"] as DateTime;
      final dateB = b["date"] as DateTime;
      return dateB.compareTo(dateA);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: softGreen,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
                    child: Row(
                      children: [
                        Icon(
                          categoryIcon(report.name),
                          color: selectedType == ReportType.income
                              ? primaryGreen
                              : Colors.redAccent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            report.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final item = transactions[index];
                        final isIncome = item["type"] == "income";
                        final amount = (item["amount"] as num).toDouble();
                        final date = item["date"] as DateTime;

                        return Card(
                          color: Colors.white,
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ListTile(
                            onTap: () async {
                              Navigator.pop(context);
                              await editTransaction(item);
                              if (!this.context.mounted) return;
                            },
                            leading: Icon(
                              categoryIcon(item["category"].toString()),
                              color: isIncome ? primaryGreen : Colors.redAccent,
                            ),
                            title: Text(
                              item["category"].toString(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "${DateFormat("dd/MM/yyyy").format(date)}  ${item["note"] ?? ""}",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            trailing: Text(
                              "${isIncome ? "+" : "-"}${formatMoney(amount)}",
                              style: TextStyle(
                                color: isIncome ? primaryGreen : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData categoryIcon(String category) {
    switch (category) {
      case "Ăn uống":
        return Icons.restaurant;
      case "Đi lại":
        return Icons.directions_bus;
      case "Quần áo":
        return Icons.checkroom;
      case "Mỹ phẩm":
        return Icons.brush;
      case "Y tế":
        return Icons.local_hospital;
      case "Giáo dục":
        return Icons.school;
      case "Tiền điện":
        return Icons.flash_on;
      case "Tiền nhà":
        return Icons.home;
      case "Tiền lương":
        return Icons.account_balance_wallet;
      case "Tiền phụ cấp":
        return Icons.savings;
      case "Tiền thưởng":
        return Icons.card_giftcard;
      case "Thu nhập phụ":
        return Icons.monetization_on;
      case "Đầu tư":
        return Icons.trending_up;
      default:
        return Icons.more_horiz;
    }
  }

  Color chartColor(int index, ReportType type) {
    if (type == ReportType.income) {
      const colors = [
        primaryGreen,
        Color(0xFF2EAD4B),
        Color(0xFF43A047),
        Color(0xFF009688),
        Color(0xFF66BB6A),
      ];
      return colors[index % colors.length];
    }

    const colors = [
      Colors.redAccent,
      Color(0xFFFF9800),
      Color(0xFF00ACC1),
      Color(0xFFFFB300),
      Color(0xFFEF5350),
      Color(0xFF7CB342),
    ];
    return colors[index % colors.length];
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
          "Báo cáo",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("transactions")
            .where("userId", isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = normalizeTransactions(snapshot.data!);
          final totalExpense = transactions
              .where((item) => item["type"] == "expense")
              .fold<double>(
                0,
                (total, item) => total + (item["amount"] as num).toDouble(),
              );
          final totalIncome = transactions
              .where((item) => item["type"] == "income")
              .fold<double>(
                0,
                (total, item) => total + (item["amount"] as num).toDouble(),
              );
          final balance = totalIncome - totalExpense;
          final currentType = selectedType == ReportType.expense
              ? "expense"
              : "income";
          final categoryReports = buildCategoryReports(
            transactions,
            currentType,
          ).values.toList();
          final chartTotal = categoryReports.fold<double>(
            0,
            (total, item) => total + item.amount,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PeriodSelector(
                  selectedPeriod: selectedPeriod,
                  onChanged: (period) {
                    setState(() {
                      selectedPeriod = period;
                    });
                  },
                ),
                const SizedBox(height: 14),
                _PeriodNavigator(
                  title: periodTitle,
                  range: periodRange,
                  onPrevious: previousPeriod,
                  onNext: nextPeriod,
                ),
                const SizedBox(height: 14),
                _OverviewSection(
                  totalExpense: totalExpense,
                  totalIncome: totalIncome,
                  balance: balance,
                  formatMoney: formatMoney,
                ),
                const SizedBox(height: 16),
                _ReportTabs(
                  selectedType: selectedType,
                  onChanged: (type) {
                    setState(() {
                      selectedType = type;
                    });
                  },
                ),
                const SizedBox(height: 14),
                _ChartCard(
                  reports: categoryReports,
                  total: chartTotal,
                  type: selectedType,
                  formatMoney: formatMoney,
                  chartColor: chartColor,
                ),
                const SizedBox(height: 14),
                if (categoryReports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        "Chưa có dữ liệu báo cáo",
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    ),
                  )
                else
                  ...categoryReports.asMap().entries.map((entry) {
                    final index = entry.key;
                    final report = entry.value;
                    final percent = chartTotal == 0
                        ? 0.0
                        : report.amount / chartTotal * 100.0;

                    return _CategoryTile(
                      report: report,
                      icon: categoryIcon(report.name),
                      iconColor: chartColor(index, selectedType),
                      percent: percent,
                      formatMoney: formatMoney,
                      onTap: () => showCategoryDetails(report),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final ReportPeriod selectedPeriod;
  final ValueChanged<ReportPeriod> onChanged;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ReportScreenState.lineGreen),
      ),
      child: Row(
        children: [
          _periodButton("Hàng Tháng", ReportPeriod.month),
          _periodButton("Hàng Năm", ReportPeriod.year),
        ],
      ),
    );
  }

  Widget _periodButton(String label, ReportPeriod period) {
    final isSelected = selectedPeriod == period;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(period),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? _ReportScreenState.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : _ReportScreenState.primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodNavigator extends StatelessWidget {
  final String title;
  final String range;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PeriodNavigator({
    required this.title,
    required this.range,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          color: _ReportScreenState.primaryGreen,
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
                    color: Colors.black87,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                range,
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          color: _ReportScreenState.primaryGreen,
        ),
      ],
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final double totalExpense;
  final double totalIncome;
  final double balance;
  final String Function(double value) formatMoney;

  const _OverviewSection({
    required this.totalExpense,
    required this.totalIncome,
    required this.balance,
    required this.formatMoney,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _OverviewCard(
                title: "Chi tiêu",
                amount: "-${formatMoney(totalExpense)}",
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OverviewCard(
                title: "Thu nhập",
                amount: "+${formatMoney(totalIncome)}",
                color: _ReportScreenState.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _OverviewCard(
          title: "Thu chi",
          amount: formatMoney(balance),
          color: balance >= 0 ? _ReportScreenState.primaryGreen : Colors.red,
          isWide: true,
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String amount;
  final Color color;
  final bool isWide;

  const _OverviewCard({
    required this.title,
    required this.amount,
    required this.color,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ReportScreenState.lineGreen),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              amount,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: isWide ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTabs extends StatelessWidget {
  final ReportType selectedType;
  final ValueChanged<ReportType> onChanged;

  const _ReportTabs({required this.selectedType, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tab("Chi tiêu", ReportType.expense),
        _tab("Thu nhập", ReportType.income),
      ],
    );
  }

  Widget _tab(String label, ReportType type) {
    final isSelected = selectedType == type;

    return Expanded(
      child: InkWell(
        onTap: () => onChanged(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? _ReportScreenState.primaryGreen
                    : Colors.black12,
                width: isSelected ? 3 : 1,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? _ReportScreenState.primaryGreen
                  : Colors.black54,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final List<_CategoryReport> reports;
  final double total;
  final ReportType type;
  final String Function(double value) formatMoney;
  final Color Function(int index, ReportType type) chartColor;

  const _ChartCard({
    required this.reports,
    required this.total,
    required this.type,
    required this.formatMoney,
    required this.chartColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ReportScreenState.lineGreen),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: reports.isEmpty
          ? const Center(
              child: Text(
                "Chưa có dữ liệu báo cáo",
                style: TextStyle(color: Colors.black54),
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 62,
                    startDegreeOffset: -90,
                    sections: reports.asMap().entries.map((entry) {
                      final index = entry.key;
                      final report = entry.value;
                      return PieChartSectionData(
                        value: report.amount,
                        color: chartColor(index, type),
                        radius: 58,
                        title: "",
                      );
                    }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Tổng",
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 120,
                      child: Text(
                        formatMoney(total),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: type == ReportType.income
                              ? _ReportScreenState.primaryGreen
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final _CategoryReport report;
  final IconData icon;
  final Color iconColor;
  final double percent;
  final String Function(double value) formatMoney;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.report,
    required this.icon,
    required this.iconColor,
    required this.percent,
    required this.formatMoney,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Icon(icon, color: iconColor, size: 30),
        title: Text(
          report.name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  formatMoney(report.amount),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "${percent.toStringAsFixed(1)}%",
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryReport {
  final String name;
  double amount;
  final List<Map<String, dynamic>> transactions;

  _CategoryReport({
    required this.name,
    required this.amount,
    required this.transactions,
  });
}
