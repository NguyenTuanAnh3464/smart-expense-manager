import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account_model.dart';
import '../models/saving_goal_model.dart';
import 'budget_service.dart';

class SavingGoalService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SavingGoalService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _goals {
    return _firestore.collection("saving_goals");
  }

  CollectionReference<Map<String, dynamic>> get _accounts {
    return _firestore.collection("accounts");
  }

  CollectionReference<Map<String, dynamic>> get _transactions {
    return _firestore.collection("transactions");
  }

  CollectionReference<Map<String, dynamic>> get _contributions {
    return _firestore.collection("saving_goal_contributions");
  }

  Stream<List<SavingGoalModel>> getGoalsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _goals.where("userId", isEqualTo: uid).snapshots().map((snapshot) {
      final goals = snapshot.docs
          .map(SavingGoalModel.fromFirestore)
          .where((goal) => goal.userId == uid)
          .toList();
      goals.sort((a, b) => a.deadline.compareTo(b.deadline));
      return goals;
    });
  }

  Future<List<SavingGoalModel>> getGoalsOnce() async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _goals.where("userId", isEqualTo: uid).get();
    final goals = snapshot.docs
        .map(SavingGoalModel.fromFirestore)
        .where((goal) => goal.userId == uid)
        .toList();
    goals.sort((a, b) => a.deadline.compareTo(b.deadline));
    return goals;
  }

  Future<void> addGoal(SavingGoalModel goal) async {
    final uid = _requireUid();
    _validate(goal);
    await _goals.add({
      ...goal.copyWith(userId: uid).toFirestore(),
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGoal(SavingGoalModel goal) async {
    final uid = _requireUid();
    final id = goal.id;
    if (id == null || id.isEmpty) return;
    _validate(goal);

    await _firestore.runTransaction((transaction) async {
      final ref = _goals.doc(id);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw StateError("Mục tiêu tiết kiệm không tồn tại");
      }
      final current = SavingGoalModel.fromFirestore(snapshot);
      if (current.userId != uid) {
        throw StateError("Bạn không có quyền sửa mục tiêu này");
      }
      transaction.update(ref, {
        ...goal.copyWith(userId: uid).toFirestore(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteGoal(String id) async {
    final uid = _requireUid();
    await _firestore.runTransaction((transaction) async {
      final ref = _goals.doc(id);
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final goal = SavingGoalModel.fromFirestore(snapshot);
      if (goal.userId != uid) {
        throw StateError("Bạn không có quyền xóa mục tiêu này");
      }
      transaction.delete(ref);
    });
  }

  Future<void> transferToGoal({
    required String goalId,
    required double amount,
    required double maxBudgetAmount,
    String? budgetId,
    required String sourceBudgetCategory,
    required int budgetMonth,
    required int budgetYear,
    String? accountId,
    String? note,
  }) async {
    final uid = _requireUid();
    if (goalId.trim().isEmpty) {
      throw ArgumentError("Vui lòng chọn mục tiêu tiết kiệm");
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError("Số tiền chuyển phải lớn hơn 0");
    }
    if (!maxBudgetAmount.isFinite || maxBudgetAmount <= 0) {
      throw ArgumentError("Ngân sách không còn tiền để chuyển");
    }
    if (amount > maxBudgetAmount) {
      throw ArgumentError("Số tiền chuyển vượt quá ngân sách còn lại");
    }

    final transferDate = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final goalRef = _goals.doc(goalId);
      final goalSnapshot = await transaction.get(goalRef);
      if (!goalSnapshot.exists) {
        throw StateError("Mục tiêu tiết kiệm không tồn tại");
      }

      final goal = SavingGoalModel.fromFirestore(goalSnapshot);
      if (goal.userId != uid) {
        throw StateError("Bạn không có quyền cập nhật mục tiêu này");
      }

      final missingAmount = goal.targetAmount - goal.currentAmount;
      if (missingAmount <= 0) {
        throw StateError("Mục tiêu này đã hoàn thành");
      }
      if (amount > missingAmount) {
        throw ArgumentError("Số tiền chuyển vượt quá số tiền còn thiếu của mục tiêu");
      }

      DocumentReference<Map<String, dynamic>>? accountRef;
      double? accountBalance;
      if (accountId != null && accountId.isNotEmpty) {
        accountRef = _accounts.doc(accountId);
        final accountSnapshot = await transaction.get(accountRef);
        if (!accountSnapshot.exists) {
          throw StateError("Tài khoản tiền không tồn tại");
        }

        final account = AccountModel.fromFirestore(accountSnapshot);
        if (account.userId != uid) {
          throw StateError("Bạn không có quyền dùng tài khoản này");
        }
        if (amount > account.balance) {
          throw ArgumentError("Số tiền chuyển vượt quá số dư tài khoản");
        }
        accountBalance = account.balance;
      }

      final now = FieldValue.serverTimestamp();
      final transferRef = _transactions.doc();
      final contributionRef = _contributions.doc(transferRef.id);
      final transferNote = note?.trim().isNotEmpty == true
          ? note!.trim()
          : "Chuyển vào mục tiêu tiết kiệm";

      transaction.update(goalRef, {
        "currentAmount": goal.currentAmount + amount,
        "updatedAt": now,
      });

      if (accountRef != null) {
        transaction.update(accountRef, {
          "balance": accountBalance! - amount,
          "updatedAt": now,
        });
      }

      transaction.set(transferRef, {
        "userId": uid,
        "id": transferRef.id,
        "goalId": goalId,
        if (budgetId != null && budgetId.isNotEmpty) "budgetId": budgetId,
        if (accountId != null && accountId.isNotEmpty) "accountId": accountId,
        "category": "Tiết kiệm",
        "amount": amount,
        "date": Timestamp.fromDate(transferDate),
        "note": transferNote,
        "type": "saving",
        "sourceBudgetCategory": sourceBudgetCategory,
        "sourceBudgetMonth": budgetMonth,
        "sourceBudgetYear": budgetYear,
        "createdAt": now,
        "updatedAt": now,
      });

      transaction.set(contributionRef, {
        "userId": uid,
        "id": contributionRef.id,
        "goalId": goalId,
        "transactionId": transferRef.id,
        if (budgetId != null && budgetId.isNotEmpty) "budgetId": budgetId,
        if (accountId != null && accountId.isNotEmpty) "accountId": accountId,
        "amount": amount,
        "date": Timestamp.fromDate(transferDate),
        "note": transferNote,
        "sourceBudgetCategory": sourceBudgetCategory,
        "sourceBudgetMonth": budgetMonth,
        "sourceBudgetYear": budgetYear,
        "createdAt": now,
      });
    });

    try {
      await BudgetService.checkBudgetAlert(
        uid,
        DateTime(budgetYear, budgetMonth),
        category: sourceBudgetCategory,
      );
    } catch (_) {}
  }

  void _validate(SavingGoalModel goal) {
    if (goal.title.trim().isEmpty) {
      throw ArgumentError("Tên mục tiêu không được để trống");
    }
    if (!goal.targetAmount.isFinite || goal.targetAmount <= 0) {
      throw ArgumentError("Số tiền mục tiêu phải lớn hơn 0");
    }
    if (!goal.currentAmount.isFinite || goal.currentAmount < 0) {
      throw ArgumentError("Số tiền hiện có không hợp lệ");
    }
  }

  String _requireUid() {
    final uid = _uid;
    if (uid == null) {
      throw StateError("Người dùng chưa đăng nhập");
    }
    return uid;
  }
}
