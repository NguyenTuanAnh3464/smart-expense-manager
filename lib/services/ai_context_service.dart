import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account_model.dart';
import '../models/saving_goal_model.dart';
import '../models/transaction_model.dart';
import 'account_service.dart';
import 'saving_goal_service.dart';
import 'transaction_service.dart';

class AIFinancialContext {
  final List<TransactionModel> transactions;
  final List<AccountModel> accounts;
  final List<Map<String, dynamic>> budgets;
  final List<SavingGoalModel> savingGoals;

  const AIFinancialContext({
    required this.transactions,
    required this.accounts,
    required this.budgets,
    required this.savingGoals,
  });

  bool get hasTransactions => transactions.isNotEmpty;
}

class AIContextService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final TransactionService _transactionService;
  final AccountService _accountService;
  final SavingGoalService _savingGoalService;

  AIContextService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    TransactionService? transactionService,
    AccountService? accountService,
    SavingGoalService? savingGoalService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _transactionService = transactionService ?? TransactionService(),
       _accountService = accountService ?? AccountService(),
       _savingGoalService = savingGoalService ?? SavingGoalService();

  Future<AIFinancialContext> loadContext() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError("Người dùng chưa đăng nhập");
    }

    final transactions = await _transactionService.getTransactionsOnce();
    final accounts = await _accountService.getAccountsOnce();
    final budgets = await _loadBudgets(uid);
    final savingGoals = await _savingGoalService.getGoalsOnce();

    return AIFinancialContext(
      transactions: transactions.take(100).toList(),
      accounts: accounts,
      budgets: budgets,
      savingGoals: savingGoals,
    );
  }

  Future<List<Map<String, dynamic>>> _loadBudgets(String uid) async {
    final snapshot = await _firestore
        .collection("budgets")
        .where("userId", isEqualTo: uid)
        .get();
    final now = DateTime.now();

    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          return data["month"] == now.month && data["year"] == now.year;
        })
        .map((doc) {
          final data = doc.data();
          return {
            "category": data["category"]?.toString() ?? "",
            "amount": data["amount"],
            "month": data["month"],
            "year": data["year"],
            "type": data["type"],
          };
        })
        .toList();
  }
}
