import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../widgets/category_icon_helper.dart';
import '../widgets/transaction_style.dart';
import 'add_transaction_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const Color primaryGreen = Color(0xFF168A36);
  final TransactionService transactionService = TransactionService();

  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDate = DateTime.now();

  String getVietnameseWeekday(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return "Th\u1ee9 2";
      case DateTime.tuesday:
        return "Th\u1ee9 3";
      case DateTime.wednesday:
        return "Th\u1ee9 4";
      case DateTime.thursday:
        return "Th\u1ee9 5";
      case DateTime.friday:
        return "Th\u1ee9 6";
      case DateTime.saturday:
        return "Th\u1ee9 7";
      case DateTime.sunday:
        return "CN";
      default:
        return "";
    }
  }

  String formatDateWithWeekday(DateTime date) {
    final day = date.day.toString().padLeft(2, "0");
    final month = date.month.toString().padLeft(2, "0");
    final year = date.year.toString();
    final weekday = getVietnameseWeekday(date);
    return "$day/$month/$year ($weekday)";
  }

  String formatMoney(double value) {
    final formatter = NumberFormat("#,###", "en_US");
    return "${formatter.format(value)}đ";
  }

  String formatCompactMoney(double value, {required bool isIncome}) {
    final absValue = value.abs();
    final prefix = isIncome ? "+" : "-";

    if (absValue >= 1000000) {
      final millions = absValue / 1000000;
      final text = millions == millions.roundToDouble()
          ? millions.toStringAsFixed(0)
          : millions.toStringAsFixed(1);
      return "$prefix${text}tr";
    }

    if (absValue >= 1000) {
      return "$prefix${(absValue / 1000).round()}k";
    }

    return "$prefix${absValue.toStringAsFixed(0)}";
  }

  DateTime get firstDayOfMonth {
    return DateTime(currentMonth.year, currentMonth.month, 1);
  }

  DateTime get lastDayOfMonth {
    return DateTime(currentMonth.year, currentMonth.month + 1, 0);
  }

  void previousMonth() {
    setState(() {
      final newMonth = DateTime(currentMonth.year, currentMonth.month - 1);
      currentMonth = newMonth;
      if (selectedDate.year != newMonth.year ||
          selectedDate.month != newMonth.month) {
        selectedDate = newMonth;
      }
    });
  }

  void nextMonth() {
    setState(() {
      final newMonth = DateTime(currentMonth.year, currentMonth.month + 1);
      currentMonth = newMonth;
      if (selectedDate.year != newMonth.year ||
          selectedDate.month != newMonth.month) {
        selectedDate = newMonth;
      }
    });
  }

  Future<void> openAddTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTransactionScreen(type: "expense", initialDate: selectedDate),
      ),
    );
    if (!mounted) return;

    if (result == null) return;

    final resultDate = result["date"];
    if (resultDate is DateTime) {
      setState(() {
        selectedDate = resultDate;
        currentMonth = DateTime(resultDate.year, resultDate.month);
      });
    }

    try {
      await transactionService.addTransaction(result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể thêm giao dịch: $error")),
      );
    }
    if (!mounted) return;
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
    if (!mounted) return;

    if (result == null) return;

    final resultDate = result["date"];
    if (resultDate is DateTime) {
      setState(() {
        selectedDate = resultDate;
        currentMonth = DateTime(resultDate.year, resultDate.month);
      });
    }

    try {
      await transactionService.updateTransaction(transaction["id"], result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể sửa giao dịch: $error")),
      );
    }
    if (!mounted) return;
  }

  Future<void> confirmDeleteTransaction(
    Map<String, dynamic> transaction,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Xóa giao dịch"),
          content: const Text("Bạn có chắc muốn xóa giao dịch này không?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Hủy"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Xóa", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    if (!mounted) return;

    if (shouldDelete != true) return;

    try {
      await transactionService.deleteTransaction(transaction["id"]);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể xóa giao dịch: $error")),
      );
    }
    if (!mounted) return;
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
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Lịch",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddTransaction,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("user_settings")
            .doc(user.uid)
            .snapshots(),
        builder: (context, settingSnapshot) {
          final settings = settingSnapshot.data?.data() ?? const {};

          return StreamBuilder<List<TransactionModel>>(
            stream: transactionService.getTransactionsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text("Không thể tải giao dịch: ${snapshot.error}"),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allTransactions = snapshot.data!.map((transaction) {
                return {
                  "id": transaction.id,
                  "userId": transaction.userId,
                  "category": transaction.category,
                  "amount": transaction.amount,
                  "note": transaction.note,
                  "type": transaction.type,
                  "date": transaction.date,
                  if (transaction.accountId != null)
                    "accountId": transaction.accountId,
                  if (transaction.categoryId != null)
                    "categoryId": transaction.categoryId,
                  if (transaction.categoryName != null)
                    "categoryName": transaction.categoryName,
                  if (transaction.categoryType != null)
                    "categoryType": transaction.categoryType,
                  if (transaction.categoryIconName != null)
                    "categoryIconName": transaction.categoryIconName,
                  if (transaction.categoryColorValue != null)
                    "categoryColorValue": transaction.categoryColorValue,
                  if (transaction.goalId != null) "goalId": transaction.goalId,
                  if (transaction.source != null) "source": transaction.source,
                  if (transaction.rawBankContent != null)
                    "rawBankContent": transaction.rawBankContent,
                  if (transaction.rawBankText != null)
                    "rawBankText": transaction.rawBankText,
                  if (transaction.bankTransactionTime != null)
                    "bankTransactionTime": transaction.bankTransactionTime,
                  if (transaction.bankAccountNumber != null)
                    "bankAccountNumber": transaction.bankAccountNumber,
                  if (transaction.bankFee != null) "bankFee": transaction.bankFee,
                  if (transaction.balanceAfterFromBank != null)
                    "balanceAfterFromBank": transaction.balanceAfterFromBank,
                  if (transaction.bankImageUrl != null)
                    "bankImageUrl": transaction.bankImageUrl,
                };
              }).toList();

              final monthTransactions = allTransactions.where((item) {
                final date = item["date"] as DateTime;
                return date.year == currentMonth.year &&
                    date.month == currentMonth.month;
              }).toList();

              final selectedTransactions = allTransactions.where((item) {
                final date = item["date"] as DateTime;
                return DateUtils.isSameDay(date, selectedDate);
              }).toList();

              double selectedIncome = 0;
              double selectedExpense = 0;

              for (var item in selectedTransactions) {
                final amount = (item["amount"] as num).toDouble();

                if (item["type"] == "income") {
                  selectedIncome += amount;
                } else if (item["type"] == "expense") {
                  selectedExpense += amount;
                }
              }

              final selectedTotal = selectedIncome - selectedExpense;

              return Column(
                children: [
                  Container(
                    color: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: previousMonth,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              DateFormat("MM/yyyy").format(currentMonth),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: nextMonth,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _buildCalendar(monthTransactions, settings),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _summaryRow(
                      income: selectedIncome,
                      expense: selectedExpense,
                      total: selectedTotal,
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Giao d\u1ecbch ng\u00e0y ${formatDateWithWeekday(selectedDate)}",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  Expanded(child: _buildTransactionList(selectedTransactions)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCalendar(
    List<Map<String, dynamic>> transactions,
    Map<String, dynamic> settings,
  ) {
    final theme = Theme.of(context);
    final weekStartsSunday = settings["calendarWeekStart"] == "sunday";
    final amountDisplay = settings["calendarAmountDisplay"] ?? "income_expense";
    final firstWeekday = weekStartsSunday
        ? firstDayOfMonth.weekday % 7
        : firstDayOfMonth.weekday - 1;
    final daysInMonth = lastDayOfMonth.day;

    final totalCells = firstWeekday + daysInMonth;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.05,
            ),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Row(
              children: weekStartsSunday
                  ? const [
                      _WeekDay("CN"),
                      _WeekDay("T2"),
                      _WeekDay("T3"),
                      _WeekDay("T4"),
                      _WeekDay("T5"),
                      _WeekDay("T6"),
                      _WeekDay("T7"),
                    ]
                  : const [
                      _WeekDay("T2"),
                      _WeekDay("T3"),
                      _WeekDay("T4"),
                      _WeekDay("T5"),
                      _WeekDay("T6"),
                      _WeekDay("T7"),
                      _WeekDay("CN"),
                    ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalCells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.96,
              ),
              itemBuilder: (context, index) {
                if (index < firstWeekday) {
                  return const SizedBox.shrink();
                }

                final day = index - firstWeekday + 1;
                final cellDate = DateTime(
                  currentMonth.year,
                  currentMonth.month,
                  day,
                );

                final dayTransactions = transactions.where((item) {
                  final date = item["date"] as DateTime;
                  return DateUtils.isSameDay(date, cellDate);
                }).toList();

                double income = 0;
                double expense = 0;

                for (var item in dayTransactions) {
                  final amount = (item["amount"] as num).toDouble();

                  if (item["type"] == "income") {
                    income += amount;
                  } else if (item["type"] == "expense") {
                    expense += amount;
                  }
                }

                return _dayCell(
                  cellDate,
                  income:
                      amountDisplay == "expense_only" ||
                          amountDisplay == "hidden"
                      ? 0
                      : income,
                  expense:
                      amountDisplay == "income_only" ||
                          amountDisplay == "hidden"
                      ? 0
                      : expense,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(DateTime date, {double income = 0, double expense = 0}) {
    final isSelected = DateUtils.isSameDay(date, selectedDate);
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final theme = Theme.of(context);
    final textColor = isSelected ? Colors.white : theme.colorScheme.onSurface;

    return InkWell(
      onTap: () {
        setState(() {
          selectedDate = date;
        });
      },
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? primaryGreen
                : isToday
                ? primaryGreen
                : theme.dividerColor,
            width: isToday && !isSelected ? 1.2 : 0.7,
          ),
          color: isSelected ? primaryGreen : theme.cardColor,
        ),
        padding: const EdgeInsets.all(3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${date.day}",
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (income > 0)
                        Text(
                          formatCompactMoney(income, isIncome: true),
                          maxLines: 1,
                          style: TextStyle(
                            color: isSelected ? Colors.white : primaryGreen,
                            fontSize: 11,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (expense > 0)
                        Text(
                          formatCompactMoney(expense, isIncome: false),
                          maxLines: 1,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.redAccent,
                            fontSize: 11,
                            height: 1.05,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow({
    required double income,
    required double expense,
    required double total,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          _summaryItem("Thu nhập", income, primaryGreen),
          _summaryItem("Chi tiêu", expense, Colors.redAccent),
          _summaryItem("Tổng", total, total >= 0 ? primaryGreen : Colors.red),
        ],
      ),
    );
  }

  Widget _summaryItem(String title, double amount, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
          Text(
            formatMoney(amount),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> transactions) {
    final sorted = [...transactions];
    sorted.sort((a, b) {
      final dateA = a["date"] as DateTime;
      final dateB = b["date"] as DateTime;
      return dateB.compareTo(dateA);
    });

    if (sorted.isEmpty) {
      return Center(
        child: Text(
          "Ngày này chưa có giao dịch",
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        final type = item["type"];
        final transactionColor = getTransactionColorFromData(
          type: type,
          categoryColorValue: item["categoryColorValue"],
        );
        final amount = (item["amount"] as num).toDouble();
        final date = item["date"] as DateTime;

        return Slidable(
          key: ValueKey(item["id"]),
          endActionPane: ActionPane(
            motion: const StretchMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => confirmDeleteTransaction(item),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: "Xóa",
              ),
            ],
          ),
          child: Card(
            color: Theme.of(context).cardColor,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              onTap: () => editTransaction(item),
              leading: Icon(
                getTransactionIconFromData(
                  type: type,
                  categoryIconName: item["categoryIconName"]?.toString(),
                ),
                color: transactionColor,
                size: 30,
              ),
              title: Text(
                item["category"],
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                item["note"].toString().isEmpty
                    ? formatDateWithWeekday(date)
                    : item["note"],
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
              trailing: Text(
                "${TransactionStyle.signFor(type)}${formatMoney(amount)}",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: transactionColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeekDay extends StatelessWidget {
  final String text;

  const _WeekDay(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: _CalendarScreenState.primaryGreen,
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: text == "CN" ? Colors.red : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}



