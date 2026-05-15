import 'package:flutter/material.dart';
import 'add_transaction_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'login_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  Widget summaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 4),
                  Text(
                    amount,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget actionButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.green,
          elevation: 1,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    loadTransactions();
  }
  Future<void> loadTransactions() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final snapshot = await firestore
        .collection("transactions")
        .where("userId", isEqualTo: user.uid)
        .get();

    final data = snapshot.docs.map((doc) {
      final item = doc.data();

      return {
        ...item,
        "id": doc.id,
        "date": item["date"].toDate(),
      };
    }).toList();

    setState(() {
      transactions = List<Map<String, dynamic>>.from(data);
    });
  }

  double get balance {
    double total = 0;

    for (var item in transactions) {
      if (item["type"] == "income") {
        total += (item["amount"] as num).toDouble();
      } else {
        total -= (item["amount"] as num).toDouble();
      }
    }

    return total;
  }

  double get totalIncome {
    double total = 0;
    for (var item in transactions) {
      if (item["type"] == "income") {
        total += (item["amount"] as num).toDouble();
      }
    }
    return total;
  }

  double get totalExpense {
    double total = 0;
    for (var item in transactions) {
      if (item["type"] == "expense") {
        total += (item["amount"] as num).toDouble();
      }
    }
    return total;
  }

  Future<void> editTransaction(int index) async {
    final oldTransaction = transactions[index];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          type: oldTransaction["type"],
          transaction: oldTransaction,
        ),
      ),
    );

    if (result != null) {
      final id = oldTransaction["id"];

      if (id != null) {
        await firestore
            .collection("transactions")
            .doc(id)
            .update(result);
      }

      setState(() {
        transactions[index] = {
          ...result,
          "id": id,
        };
      });
    }
  }

  Future<void> openAddTransaction(String type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(type: type),
      ),
    );

    if (result != null) {


      await addTransactionToFirestore(result);

      setState(() {
        transactions.add(result);
      });
    }
  }

  String formatMoney(double amount) {
    final formatter = NumberFormat("#,###", "en_US");

    return "${formatter.format(amount)} VNĐ";
  }

  Future<void> addTransactionToFirestore(
      Map<String, dynamic> transaction,
      ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await firestore.collection("transactions").add({
      ...transaction,
      "userId": user.uid,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: const Text("Smart Expense Manager"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();

              if (!context.mounted) return;

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2EAD4B),
                      Color(0xFF168A36),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),

                child: Row(
                  children: [

                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          const Text(
                            "Người dùng",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),

                          const SizedBox(height: 2),

                          Text(
                            FirebaseAuth.instance.currentUser?.email ??
                                "No Email",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        const Text(
                          "Số dư hiện tại",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          formatMoney(balance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),




          const SizedBox(height: 20),

          Row(
            children: [
              summaryCard(
                title: "Tổng thu",
                amount: formatMoney(totalIncome),
                icon: Icons.trending_up,
                color: Colors.green,
              ),

              const SizedBox(width: 12),

              summaryCard(
                title: "Tổng chi",
                amount: formatMoney(totalExpense),
                icon: Icons.trending_down,
                color: Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [

              actionButton(
                title: "Thêm thu",
                icon: Icons.add,
                onPressed: () {
                  openAddTransaction("income");
                },
              ),

              const SizedBox(width: 12),

              actionButton(
                title: "Thêm chi",
                icon: Icons.remove,
                onPressed: () {
                  openAddTransaction("expense");
                },
              ),
            ],
          ),

              const SizedBox(height: 30),

              const Text(
                "Giao dịch gần đây",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              transactions.isEmpty
                  ? const Text("Chưa có giao dịch nào")
                  : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final item = transactions[index];
                  final isIncome = item["type"] == "income";

                  return Slidable(
                    key: ValueKey(index),
                    endActionPane: ActionPane(
                      motion: const StretchMotion(),
                      children: [
                        SlidableAction(
                          onPressed: (context) async {
                            final id = item["id"];

                            if (id != null) {
                              await firestore
                                  .collection("transactions")
                                  .doc(id)
                                  .delete();
                            }

                            setState(() {
                              transactions.removeAt(index);
                            });
                          },
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          icon: Icons.delete,
                          label: "Xóa",
                        ),
                      ],
                    ),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        onTap: () {
                          editTransaction(index);
                        },
                        leading: Icon(
                          isIncome
                              ? Icons.account_balance_wallet
                              : Icons.shopping_bag,
                          color: isIncome ? Colors.green : Colors.red,
                          size: 30,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item["category"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              "${isIncome ? "+" : "-"}${formatMoney((item["amount"] as num).toDouble())}",
                              style: TextStyle(
                                color: isIncome ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        subtitle: Text(
                          item["note"].toString().isEmpty
                              ? "Không có ghi chú"
                              : item["note"],
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}