import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RecurringTransactionScreen extends StatelessWidget {
  static const Color primaryGreen = Color(0xFF168A36);
  static const Color softGreen = Color(0xFFEAF7EE);

  const RecurringTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: softGreen,
      appBar: AppBar(
        title: const Text("Giao dịch định kì"),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: user == null
          ? const Center(child: Text("Chưa đăng nhập"))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("recurring_transactions")
                  .where("userId", isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Chưa có chi phí cố định hoặc thu nhập định kì",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data();
                    return Card(
                      color: Colors.white,
                      child: ListTile(
                        leading: Icon(
                          data["type"] == "income"
                              ? Icons.savings
                              : Icons.shopping_bag,
                          color: data["type"] == "income"
                              ? primaryGreen
                              : Colors.red,
                        ),
                        title: Text(data["name"] ?? "Giao dịch định kì"),
                        subtitle: Text(data["repeatType"] ?? "monthly"),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}
