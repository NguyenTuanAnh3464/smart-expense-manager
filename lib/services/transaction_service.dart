import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account_model.dart';
import '../models/transaction_model.dart';
import 'budget_service.dart';

class TransactionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TransactionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _transactions {
    return _firestore.collection("transactions");
  }

  CollectionReference<Map<String, dynamic>> get _accounts {
    return _firestore.collection("accounts");
  }

  CollectionReference<Map<String, dynamic>> get _goals {
    return _firestore.collection("saving_goals");
  }

  CollectionReference<Map<String, dynamic>> get _contributions {
    return _firestore.collection("saving_goal_contributions");
  }

  Stream<List<TransactionModel>> getTransactionsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _transactions.where("userId", isEqualTo: uid).snapshots().map((
      snapshot,
    ) {
      final transactions = snapshot.docs
          .map(TransactionModel.fromFirestore)
          .where((item) => item.userId == uid)
          .toList();
      transactions.sort((a, b) => b.date.compareTo(a.date));
      return transactions;
    });
  }

  Future<List<TransactionModel>> getTransactionsOnce() async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _transactions.where("userId", isEqualTo: uid).get();
    final transactions = snapshot.docs
        .map(TransactionModel.fromFirestore)
        .where((item) => item.userId == uid)
        .toList();
    transactions.sort((a, b) => b.date.compareTo(a.date));
    return transactions;
  }

  Future<DocumentReference<Map<String, dynamic>>> addTransaction(
    Map<String, dynamic> data,
  ) async {
    final uid = _requireUid();
    final transaction = TransactionModel.fromMap(data, fallbackUserId: uid);
    _validateTransaction(transaction, rawData: data);
    final docRef = _transactions.doc();

    await _firestore.runTransaction((firestoreTransaction) async {
      final accountUpdate = await _readAccountForDelta(
        firestoreTransaction,
        uid: uid,
        accountId: transaction.accountId,
        delta: _signedDelta(transaction),
      );
      final savingUpdate = await _readSavingGoalForDelta(
        firestoreTransaction,
        uid: uid,
        goalId: transaction.goalId,
        delta: transaction.isSaving ? transaction.amount : 0,
      );
      final contributionRef = transaction.isSaving
          ? _contributions.doc(docRef.id)
          : null;

      firestoreTransaction.set(docRef, {
        ...transaction.copyWith(userId: uid).toFirestore(),
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
      _applyAccountUpdate(firestoreTransaction, accountUpdate);
      _applySavingGoalUpdate(firestoreTransaction, savingUpdate);
      if (contributionRef != null) {
        _setContribution(
          firestoreTransaction,
          contributionRef,
          uid: uid,
          transactionId: docRef.id,
          transaction: transaction,
        );
      }
    });

    await _checkBudgetAlertSafely(uid, transaction, data);
    return docRef;
  }

  Future<void> updateTransaction(String id, Map<String, dynamic> data) async {
    final uid = _requireUid();
    final newTransaction = TransactionModel.fromMap(data, fallbackUserId: uid);
    _validateTransaction(newTransaction, rawData: data);
    TransactionModel? oldTransactionForAlert;
    TransactionModel? newTransactionForAlert;
    Map<String, dynamic>? oldDataForAlert;
    Map<String, dynamic>? newDataForAlert;

    await _firestore.runTransaction((firestoreTransaction) async {
      final docRef = _transactions.doc(id);
      final oldSnapshot = await firestoreTransaction.get(docRef);
      if (!oldSnapshot.exists) {
        throw StateError("Giao dịch không tồn tại");
      }

      final oldTransaction = TransactionModel.fromFirestore(oldSnapshot);
      final oldData = oldSnapshot.data() ?? {};
      if (oldTransaction.userId != uid) {
        throw StateError("Bạn không có quyền sửa giao dịch này");
      }

      final effectiveNewTransaction = _mergeSavingMetadata(
        oldTransaction,
        newTransaction,
      );
      final oldAccountId = oldTransaction.accountId;
      final newAccountId = effectiveNewTransaction.accountId;
      final sameAccount =
          oldAccountId != null &&
          oldAccountId.isNotEmpty &&
          oldAccountId == newAccountId;
      final oldAccountUpdate = sameAccount
          ? null
          : await _readAccountForDelta(
              firestoreTransaction,
              uid: uid,
              accountId: oldAccountId,
              delta: -_signedDelta(oldTransaction),
            );
      final newAccountUpdate = sameAccount
          ? await _readAccountForDelta(
              firestoreTransaction,
              uid: uid,
              accountId: newAccountId,
              delta:
                  _signedDelta(effectiveNewTransaction) -
                  _signedDelta(oldTransaction),
            )
          : await _readAccountForDelta(
              firestoreTransaction,
              uid: uid,
              accountId: newAccountId,
              delta: _signedDelta(effectiveNewTransaction),
            );
      final savingUpdates = await _readSavingGoalUpdatesForChange(
        firestoreTransaction,
        uid: uid,
        oldTransaction: oldTransaction,
        newTransaction: effectiveNewTransaction,
      );

      final payload = {
        ...effectiveNewTransaction.copyWith(id: id, userId: uid).toFirestore(),
        "updatedAt": FieldValue.serverTimestamp(),
      };
      _preserveSavingMetadata(payload, oldSnapshot.data() ?? {}, data);
      _preserveBankImageMetadata(payload, oldSnapshot.data() ?? {}, data);
      if (effectiveNewTransaction.accountId == null ||
          effectiveNewTransaction.accountId!.isEmpty) {
        payload["accountId"] = FieldValue.delete();
      }

      _applyAccountUpdate(firestoreTransaction, oldAccountUpdate);
      _applyAccountUpdate(firestoreTransaction, newAccountUpdate);
      for (final update in savingUpdates) {
        _applySavingGoalUpdate(firestoreTransaction, update);
      }
      firestoreTransaction.update(docRef, payload);
      _syncContributionAfterUpdate(
        firestoreTransaction,
        uid: uid,
        transactionId: id,
        transaction: effectiveNewTransaction,
      );
      oldTransactionForAlert = oldTransaction;
      newTransactionForAlert = effectiveNewTransaction;
      oldDataForAlert = oldData;
      newDataForAlert = payload;
    });

    await _checkBudgetAlertSafely(
      uid,
      oldTransactionForAlert,
      oldDataForAlert,
    );
    await _checkBudgetAlertSafely(
      uid,
      newTransactionForAlert,
      newDataForAlert ?? data,
    );
  }

  Future<void> deleteTransaction(String id) async {
    final uid = _requireUid();
    TransactionModel? deletedTransactionForAlert;
    Map<String, dynamic>? deletedDataForAlert;

    await _firestore.runTransaction((firestoreTransaction) async {
      final docRef = _transactions.doc(id);
      final snapshot = await firestoreTransaction.get(docRef);
      if (!snapshot.exists) return;

      final oldTransaction = TransactionModel.fromFirestore(snapshot);
      final oldData = snapshot.data() ?? {};
      if (oldTransaction.userId != uid) {
        throw StateError("Bạn không có quyền xóa giao dịch này");
      }

      final accountUpdate = await _readAccountForDelta(
        firestoreTransaction,
        uid: uid,
        accountId: oldTransaction.accountId,
        delta: -_signedDelta(oldTransaction),
      );
      final savingUpdate = await _readSavingGoalForDelta(
        firestoreTransaction,
        uid: uid,
        goalId: oldTransaction.goalId,
        delta: oldTransaction.isSaving ? -oldTransaction.amount : 0,
      );
      _applyAccountUpdate(firestoreTransaction, accountUpdate);
      _applySavingGoalUpdate(firestoreTransaction, savingUpdate);
      if (oldTransaction.isSaving) {
        firestoreTransaction.delete(_contributions.doc(id));
      }
      firestoreTransaction.delete(docRef);
      deletedTransactionForAlert = oldTransaction;
      deletedDataForAlert = oldData;
    });

    await _checkBudgetAlertSafely(
      uid,
      deletedTransactionForAlert,
      deletedDataForAlert,
    );
  }

  Future<void> _checkBudgetAlertSafely(
    String uid,
    TransactionModel? transaction,
    Map<String, dynamic>? rawData,
  ) async {
    if (transaction == null) return;
    final category = _budgetCategoryFor(transaction, rawData);
    if (category == null && !transaction.isExpense && !transaction.isSaving) {
      return;
    }

    try {
      await BudgetService.checkBudgetAlert(
        uid,
        transaction.date,
        category: category,
      );
    } catch (_) {}
  }

  String? _budgetCategoryFor(
    TransactionModel transaction,
    Map<String, dynamic>? rawData,
  ) {
    if (transaction.isExpense) return transaction.category;
    if (!transaction.isSaving) return null;
    final category = rawData?["sourceBudgetCategory"]?.toString().trim();
    return category?.isNotEmpty == true ? category : null;
  }

  double _signedDelta(TransactionModel transaction) {
    if (transaction.isIncome) return transaction.amount;
    if (TransactionModel.normalizeType(transaction.type) == "saving") {
      return -transaction.amount;
    }
    return -transaction.amount;
  }

  void _validateTransaction(
    TransactionModel transaction, {
    required Map<String, dynamic> rawData,
  }) {
    if (!transaction.amount.isFinite || transaction.amount <= 0) {
      throw ArgumentError("Số tiền giao dịch phải lớn hơn 0");
    }
    if (transaction.category.trim().isEmpty) {
      throw ArgumentError("Danh mục giao dịch không được để trống");
    }
    if (TransactionModel.parseDate(rawData["date"]) == null) {
      throw ArgumentError("Ngày giao dịch không hợp lệ");
    }
    if (transaction.isSaving &&
        (transaction.goalId == null || transaction.goalId!.isEmpty)) {
      throw ArgumentError("Vui lòng chọn mục tiêu tiết kiệm");
    }
    if (!transaction.isSaving &&
        (transaction.accountId == null || transaction.accountId!.isEmpty)) {
      throw ArgumentError("Vui lòng chọn tài khoản tiền");
    }
  }

  Future<_AccountBalanceUpdate?> _readAccountForDelta(
    Transaction firestoreTransaction, {
    required String uid,
    required String? accountId,
    required double delta,
  }) async {
    if (accountId == null || accountId.isEmpty || delta == 0) return null;

    final accountRef = _accounts.doc(accountId);
    final accountSnapshot = await firestoreTransaction.get(accountRef);
    if (!accountSnapshot.exists) {
      throw StateError("Tài khoản giao dịch không tồn tại");
    }

    final account = AccountModel.fromFirestore(accountSnapshot);
    if (account.userId != uid) {
      throw StateError("Bạn không có quyền dùng tài khoản này");
    }

    return _AccountBalanceUpdate(
      ref: accountRef,
      nextBalance: account.balance + delta,
    );
  }

  void _applyAccountUpdate(
    Transaction firestoreTransaction,
    _AccountBalanceUpdate? update,
  ) {
    if (update == null) return;
    firestoreTransaction.update(update.ref, {
      "balance": update.nextBalance,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  Future<_SavingGoalUpdate?> _readSavingGoalForDelta(
    Transaction firestoreTransaction, {
    required String uid,
    required String? goalId,
    required double delta,
  }) async {
    if (goalId == null || goalId.isEmpty || delta == 0) return null;

    final goalRef = _goals.doc(goalId);
    final snapshot = await firestoreTransaction.get(goalRef);
    if (!snapshot.exists) {
      throw StateError("Mục tiêu tiết kiệm không tồn tại");
    }

    final data = snapshot.data() ?? {};
    if (data["userId"]?.toString() != uid) {
      throw StateError("Bạn không có quyền cập nhật mục tiêu này");
    }
    final currentAmount = TransactionModel.parseAmount(data["currentAmount"]);
    final nextAmount = (currentAmount + delta)
        .clamp(0.0, double.infinity)
        .toDouble();
    return _SavingGoalUpdate(ref: goalRef, nextAmount: nextAmount);
  }

  Future<List<_SavingGoalUpdate>> _readSavingGoalUpdatesForChange(
    Transaction firestoreTransaction, {
    required String uid,
    required TransactionModel oldTransaction,
    required TransactionModel newTransaction,
  }) async {
    final updates = <_SavingGoalUpdate>[];
    if (!oldTransaction.isSaving && !newTransaction.isSaving) return updates;

    final oldGoalId = oldTransaction.goalId;
    final newGoalId = newTransaction.goalId;
    if (oldGoalId != null &&
        oldGoalId.isNotEmpty &&
        oldGoalId == newGoalId) {
      final delta = ((newTransaction.isSaving ? newTransaction.amount : 0) -
              (oldTransaction.isSaving ? oldTransaction.amount : 0))
          .toDouble();
      final update = await _readSavingGoalForDelta(
        firestoreTransaction,
        uid: uid,
        goalId: oldGoalId,
        delta: delta,
      );
      if (update != null) updates.add(update);
      return updates;
    }

    final oldUpdate = await _readSavingGoalForDelta(
      firestoreTransaction,
      uid: uid,
      goalId: oldGoalId,
      delta: oldTransaction.isSaving ? -oldTransaction.amount : 0,
    );
    final newUpdate = await _readSavingGoalForDelta(
      firestoreTransaction,
      uid: uid,
      goalId: newGoalId,
      delta: newTransaction.isSaving ? newTransaction.amount : 0,
    );
    if (oldUpdate != null) updates.add(oldUpdate);
    if (newUpdate != null) updates.add(newUpdate);
    return updates;
  }

  void _applySavingGoalUpdate(
    Transaction firestoreTransaction,
    _SavingGoalUpdate? update,
  ) {
    if (update == null) return;
    firestoreTransaction.update(update.ref, {
      "currentAmount": update.nextAmount,
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  void _syncContributionAfterUpdate(
    Transaction firestoreTransaction, {
    required String uid,
    required String transactionId,
    required TransactionModel transaction,
  }) {
    final contributionRef = _contributions.doc(transactionId);
    if (!transaction.isSaving) {
      firestoreTransaction.delete(contributionRef);
      return;
    }

    final ref = contributionRef;
    _setContribution(
      firestoreTransaction,
      ref,
      uid: uid,
      transactionId: transactionId,
      transaction: transaction,
    );
  }

  void _setContribution(
    Transaction firestoreTransaction,
    DocumentReference<Map<String, dynamic>> ref, {
    required String uid,
    required String transactionId,
    required TransactionModel transaction,
  }) {
    firestoreTransaction.set(ref, {
      "id": ref.id,
      "userId": uid,
      "goalId": transaction.goalId,
      "transactionId": transactionId,
      if (transaction.accountId != null && transaction.accountId!.isNotEmpty)
        "accountId": transaction.accountId,
      "amount": transaction.amount,
      "date": Timestamp.fromDate(transaction.date),
      "note": transaction.note,
      "updatedAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  TransactionModel _mergeSavingMetadata(
    TransactionModel oldTransaction,
    TransactionModel newTransaction,
  ) {
    if (!oldTransaction.isSaving || !newTransaction.isSaving) {
      return newTransaction;
    }
    return newTransaction.copyWith(goalId: newTransaction.goalId ?? oldTransaction.goalId);
  }

  void _preserveSavingMetadata(
    Map<String, dynamic> payload,
    Map<String, dynamic> oldData,
    Map<String, dynamic> newData,
  ) {
    for (final key in [
      "budgetId",
      "sourceBudgetCategory",
      "sourceBudgetMonth",
      "sourceBudgetYear",
    ]) {
      if (!newData.containsKey(key) && oldData.containsKey(key)) {
        payload[key] = oldData[key];
      }
    }
  }

  void _preserveBankImageMetadata(
    Map<String, dynamic> payload,
    Map<String, dynamic> oldData,
    Map<String, dynamic> newData,
  ) {
    for (final key in [
      "source",
      "rawBankContent",
      "rawBankText",
      "bankTransactionTime",
      "bankAccountNumber",
      "bankFee",
      "balanceAfterFromBank",
      "bankImageUrl",
    ]) {
      if (!newData.containsKey(key) && oldData.containsKey(key)) {
        payload[key] = oldData[key];
      }
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

class _AccountBalanceUpdate {
  final DocumentReference<Map<String, dynamic>> ref;
  final double nextBalance;

  const _AccountBalanceUpdate({required this.ref, required this.nextBalance});
}

class _SavingGoalUpdate {
  final DocumentReference<Map<String, dynamic>> ref;
  final double nextAmount;

  const _SavingGoalUpdate({required this.ref, required this.nextAmount});
}
