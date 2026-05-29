import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'add_transaction_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const Color primaryGreen = Color(0xFF168A36);
  static const Color softGreen = Color(0xFFEAF7EE);
  static const Color lineGreen = Color(0xFFCDE8D4);

  DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDate = DateTime.now();

  String formatMoney(double value) {
    final formatter = NumberFormat("#,###", "en_US");
    return "${formatter.format(value)}đ";
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
    if (!context.mounted) return;

    if (result == null) return;

    final resultDate = result["date"];
    if (resultDate is DateTime) {
      setState(() {
        selectedDate = resultDate;
        currentMonth = DateTime(resultDate.year, resultDate.month);
      });
    }

    await FirebaseFirestore.instance.collection("transactions").add({
      ...result,
      "userId": user.uid,
    });
    if (!context.mounted) return;
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

    final resultDate = result["date"];
    if (resultDate is DateTime) {
      setState(() {
        selectedDate = resultDate;
        currentMonth = DateTime(resultDate.year, resultDate.month);
      });
    }

    await FirebaseFirestore.instance
        .collection("transactions")
        .doc(transaction["id"])
        .update({...result, "userId": user.uid});
    if (!context.mounted) return;
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
    if (!context.mounted) return;

    if (shouldDelete != true) return;

    await FirebaseFirestore.instance
        .collection("transactions")
        .doc(transaction["id"])
        .delete();
    if (!context.mounted) return;
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
        backgroundColor: primaryGreen,
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
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
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

          final allTransactions = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final rawDate = data["date"];

            return {
              ...data,
              "id": doc.id,
              "date": rawDate is Timestamp ? rawDate.toDate() : rawDate,
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
            } else {
              selectedExpense += amount;
            }
          }

          final selectedTotal = selectedIncome - selectedExpense;

          return Column(
            children: [
              Container(
                color: primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: previousMonth,
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormat("MM/yyyy").format(currentMonth),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: nextMonth,
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
                child: _buildCalendar(monthTransactions),
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
                    "Giao dịch ngày ${DateFormat("dd/MM/yyyy").format(selectedDate)}",
                    style: const TextStyle(
                      color: Colors.black87,
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
      ),
    );
  }

  Widget _buildCalendar(List<Map<String, dynamic>> transactions) {
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final totalCells = firstWeekday - 1 + daysInMonth;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineGreen),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              children: const [
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
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) {
                  return const SizedBox.shrink();
                }

                final day = index - firstWeekday + 2;
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
                  } else {
                    expense += amount;
                  }
                }

                return _dayCell(cellDate, income: income, expense: expense);
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
    final textColor = isSelected ? Colors.white : Colors.black87;

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
                : lineGreen,
            width: isToday && !isSelected ? 1.2 : 0.7,
          ),
          color: isSelected ? primaryGreen : Colors.white,
        ),
        padding: const EdgeInsets.all(4),
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
                          formatMoney(income),
                          maxLines: 1,
                          style: TextStyle(
                            color: isSelected ? Colors.white : primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (expense > 0)
                        Text(
                          formatMoney(expense),
                          maxLines: 1,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineGreen),
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
            style: const TextStyle(color: Colors.black87, fontSize: 14),
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
      return const Center(
        child: Text(
          "Ngày này chưa có giao dịch",
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final item = sorted[index];
        final isIncome = item["type"] == "income";
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
            color: Colors.white,
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
                isIncome ? Icons.savings : Icons.shopping_bag,
                color: isIncome ? primaryGreen : Colors.redAccent,
                size: 30,
              ),
              title: Text(
                item["category"],
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                item["note"].toString().isEmpty
                    ? DateFormat("dd/MM/yyyy").format(date)
                    : item["note"],
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
              trailing: Text(
                "${isIncome ? "+" : "-"}${formatMoney(amount)}",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isIncome ? primaryGreen : Colors.redAccent,
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
