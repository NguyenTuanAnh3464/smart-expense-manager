import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
      currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
    });
  }

  void nextMonth() {
    setState(() {
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    });
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
        centerTitle: true,
        title: const Text(
          "Lịch",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
            return {
              ...data,
              "id": doc.id,
              "date": (data["date"] as Timestamp).toDate(),
            };
          }).toList();

          final monthTransactions = allTransactions.where((item) {
            final date = item["date"] as DateTime;
            return date.year == currentMonth.year &&
                date.month == currentMonth.month;
          }).toList();

          double income = 0;
          double expense = 0;

          for (var item in monthTransactions) {
            final amount = (item["amount"] as num).toDouble();

            if (item["type"] == "income") {
              income += amount;
            } else {
              expense += amount;
            }
          }

          final total = income - expense;

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

              _buildCalendar(monthTransactions),

              _summaryRow(income: income, expense: expense, total: total),

              Expanded(child: _buildTransactionList(monthTransactions)),
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

    return Column(
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
              return _dayCell("");
            }

            final day = index - firstWeekday + 2;

            final dayTransactions = transactions.where((item) {
              final date = item["date"] as DateTime;
              return date.day == day;
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

            return _dayCell("$day", income: income, expense: expense);
          },
        ),
      ],
    );
  }

  Widget _dayCell(String day, {double income = 0, double expense = 0}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: lineGreen, width: 0.7),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day,
            style: const TextStyle(
              color: Color(0xFF1F2933),
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (expense > 0)
                      Text(
                        formatMoney(expense),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.redAccent,
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
    );
  }

  Widget _summaryRow({
    required double income,
    required double expense,
    required double total,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: lineGreen),
          bottom: BorderSide(color: lineGreen),
        ),
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
          "Tháng này chưa có giao dịch",
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

        return ListTile(
          leading: Icon(
            isIncome ? Icons.savings : Icons.shopping_bag,
            color: isIncome ? primaryGreen : Colors.redAccent,
          ),
          title: Text(
            item["category"],
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
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isIncome ? primaryGreen : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
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
