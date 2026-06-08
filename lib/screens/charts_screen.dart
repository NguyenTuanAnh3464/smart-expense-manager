import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../widgets/app_ui.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;
  final TransactionService transactionService = TransactionService();
  final DateTime currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUi.pageBackground(context),
      appBar: AppBar(
        title: const Text(
          "Biểu đồ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Danh mục"),
            Tab(text: "Xu hướng"),
            Tab(text: "So sánh"),
          ],
        ),
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: transactionService.getTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data!;
          return TabBarView(
            controller: tabController,
            children: [
              _CategoryChartTab(
                data: _buildCategoryData(transactions),
                month: currentMonth,
              ),
              _TrendChartTab(data: _buildTrendData(transactions)),
              _CompareChartTab(data: _buildCompareData(transactions)),
            ],
          );
        },
      ),
    );
  }

  List<_CategoryChartItem> _buildCategoryData(
    List<TransactionModel> transactions,
  ) {
    final totals = <String, double>{};
    for (final item in transactions) {
      if (!item.isExpense) continue;
      if (item.date.year != currentMonth.year ||
          item.date.month != currentMonth.month) {
        continue;
      }
      totals[item.category] = (totals[item.category] ?? 0) + item.amount;
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.asMap().entries.map((entry) {
      return _CategoryChartItem(
        entry.value.key,
        entry.value.value,
        _chartColor(entry.key),
      );
    }).toList();
  }

  List<_TrendChartItem> _buildTrendData(List<TransactionModel> transactions) {
    final months = List.generate(6, (index) {
      final offset = 5 - index;
      return DateTime(currentMonth.year, currentMonth.month - offset);
    });

    return months.map((month) {
      final expense = transactions
          .where(
            (item) =>
                item.isExpense &&
                item.date.year == month.year &&
                item.date.month == month.month,
          )
          .fold<double>(0, (total, item) => total + item.amount);
      return _TrendChartItem(_monthLabel(month), expense);
    }).toList();
  }

  List<_CompareChartItem> _buildCompareData(
    List<TransactionModel> transactions,
  ) {
    final months = List.generate(6, (index) {
      final offset = 5 - index;
      return DateTime(currentMonth.year, currentMonth.month - offset);
    });

    return months.map((month) {
      final monthTransactions = transactions.where(
        (item) =>
            item.date.year == month.year && item.date.month == month.month,
      );
      final income = monthTransactions
          .where((item) => item.isIncome)
          .fold<double>(0, (total, item) => total + item.amount);
      final expense = monthTransactions
          .where((item) => item.isExpense)
          .fold<double>(0, (total, item) => total + item.amount);
      return _CompareChartItem(_monthLabel(month), income, expense);
    }).toList();
  }

  String _monthLabel(DateTime month) => "T${month.month}";

  Color _chartColor(int index) {
    const colors = [
      Colors.redAccent,
      Colors.orange,
      Colors.cyan,
      Colors.amber,
      AppUi.primaryGreen,
      Colors.pink,
      Colors.blue,
    ];
    return colors[index % colors.length];
  }
}

class _CategoryChartTab extends StatelessWidget {
  final List<_CategoryChartItem> data;
  final DateTime month;

  const _CategoryChartTab({required this.data, required this.month});

  @override
  Widget build(BuildContext context) {
    final total = data.fold<double>(0, (sum, item) => sum + item.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionTitle(title: "Cơ cấu chi tiêu T${month.month}"),
              const SizedBox(height: 18),
              SizedBox(
                height: 260,
                child: data.isEmpty
                    ? const _EmptyChartState(
                        message: "Chưa có dữ liệu chi tiêu",
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 62,
                              startDegreeOffset: -90,
                              sections: data.map((item) {
                                return PieChartSectionData(
                                  value: item.amount,
                                  color: item.color,
                                  radius: 70,
                                  title: total == 0
                                      ? ""
                                      : "${(item.amount / total * 100).toStringAsFixed(0)}%",
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Tổng",
                                style: TextStyle(
                                  color: AppUi.secondaryText(context),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 130,
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
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (data.isEmpty)
          const AppPanel(child: Text("Chưa có giao dịch chi tiêu trong tháng."))
        else
          for (final item in data)
            AppPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.circle, color: item.color, size: 14),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppUi.primaryText(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    AppUi.money(item.amount),
                    style: TextStyle(
                      color: AppUi.primaryText(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _TrendChartTab extends StatelessWidget {
  final List<_TrendChartItem> data;

  const _TrendChartTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasData = data.any((item) => item.expense > 0);
    final maxY = data.fold<double>(0, (max, item) {
      return item.expense > max ? item.expense : max;
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionTitle(title: "Xu hướng chi tiêu 6 tháng"),
              const SizedBox(height: 18),
              SizedBox(
                height: 280,
                child: hasData
                    ? LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: maxY <= 0 ? 1 : maxY * 1.2,
                          gridData: FlGridData(
                            show: true,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: Theme.of(context).dividerColor,
                              strokeWidth: 0.8,
                            ),
                            getDrawingVerticalLine: (_) => FlLine(
                              color: Theme.of(context).dividerColor,
                              strokeWidth: 0.8,
                            ),
                          ),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: data
                                  .asMap()
                                  .entries
                                  .map(
                                    (entry) => FlSpot(
                                      entry.key.toDouble(),
                                      entry.value.expense,
                                    ),
                                  )
                                  .toList(),
                              isCurved: true,
                              color: AppUi.primaryGreen,
                              barWidth: 4,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppUi.primaryGreen.withValues(
                                  alpha: 0.12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const _EmptyChartState(
                        message: "Chưa có dữ liệu xu hướng",
                      ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in data)
                    Chip(
                      label: Text(
                        "${item.label}: ${AppUi.money(item.expense)}",
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompareChartTab extends StatelessWidget {
  final List<_CompareChartItem> data;

  const _CompareChartTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasData = data.any((item) => item.income > 0 || item.expense > 0);
    final maxValue = data.fold<double>(0, (max, item) {
      final localMax = item.income > item.expense ? item.income : item.expense;
      return localMax > max ? localMax : max;
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionTitle(title: "Thu nhập và chi tiêu"),
              const SizedBox(height: 18),
              SizedBox(
                height: 280,
                child: hasData
                    ? BarChart(
                        BarChartData(
                          maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
                          gridData: FlGridData(
                            show: true,
                            getDrawingHorizontalLine: (_) => FlLine(
                              color: Theme.of(context).dividerColor,
                              strokeWidth: 0.8,
                            ),
                            getDrawingVerticalLine: (_) => FlLine(
                              color: Theme.of(context).dividerColor,
                              strokeWidth: 0.8,
                            ),
                          ),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          barGroups: data.asMap().entries.map((entry) {
                            final item = entry.value;
                            return BarChartGroupData(
                              x: entry.key,
                              barsSpace: 4,
                              barRods: [
                                BarChartRodData(
                                  toY: item.income,
                                  color: AppUi.primaryGreen,
                                  width: 10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                BarChartRodData(
                                  toY: item.expense,
                                  color: Colors.redAccent,
                                  width: 10,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      )
                    : const _EmptyChartState(
                        message: "Chưa có dữ liệu so sánh",
                      ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: const [
                  _ChartLegend(label: "Thu nhập", color: AppUi.primaryGreen),
                  _ChartLegend(label: "Chi tiêu", color: Colors.redAccent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (data.isEmpty)
          const AppPanel(child: Text("Chưa có giao dịch nào."))
        else
          for (final item in data)
            AppPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: AppUi.primaryText(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    "+${AppUi.money(item.income)}",
                    style: const TextStyle(
                      color: AppUi.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    "-${AppUi.money(item.expense)}",
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final String label;
  final Color color;

  const _ChartLegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppUi.secondaryText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyChartState extends StatelessWidget {
  final String message;

  const _EmptyChartState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppUi.secondaryText(context)),
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

class _CategoryChartItem {
  final String name;
  final double amount;
  final Color color;

  const _CategoryChartItem(this.name, this.amount, this.color);
}

class _TrendChartItem {
  final String label;
  final double expense;

  const _TrendChartItem(this.label, this.expense);
}

class _CompareChartItem {
  final String label;
  final double income;
  final double expense;

  const _CompareChartItem(this.label, this.income, this.expense);
}
