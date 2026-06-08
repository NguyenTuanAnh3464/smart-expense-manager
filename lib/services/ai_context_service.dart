import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account_model.dart';
import '../models/transaction_model.dart';
import 'account_service.dart';
import 'transaction_service.dart';

class AIFinancialContext {
  final List<TransactionModel> transactions;
  final List<AccountModel> accounts;
  final List<Map<String, dynamic>> budgets;

  const AIFinancialContext({
    required this.transactions,
    required this.accounts,
    required this.budgets,
  });

  bool get hasTransactions => transactions.isNotEmpty;
}

class AIContextService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final TransactionService _transactionService;
  final AccountService _accountService;

  AIContextService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    TransactionService? transactionService,
    AccountService? accountService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _transactionService = transactionService ?? TransactionService(),
       _accountService = accountService ?? AccountService();

  Future<AIFinancialContext> loadContext() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError("Người dùng chưa đăng nhập");
    }

    final transactions = await _transactionService.getTransactionsOnce();
    final accounts = await _accountService.getAccountsOnce();
    final budgets = await _loadBudgets(uid);

    return AIFinancialContext(
      transactions: transactions.take(100).toList(),
      accounts: accounts,
      budgets: budgets,
    );
  }

  Future<List<Map<String, dynamic>>> _loadBudgets(String uid) async {
    final snapshot = await _firestore
        .collection("budgets")
        .where("userId", isEqualTo: uid)
        .limit(40)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        "category": data["category"]?.toString() ?? "",
        "amount": data["amount"],
        "month": data["month"],
        "year": data["year"],
        "type": data["type"],
      };
    }).toList();
  }
}
