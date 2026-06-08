import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account_model.dart';
import '../models/transaction_model.dart';

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
    final docRef = _transactions.doc();

    await _firestore.runTransaction((firestoreTransaction) async {
      final accountUpdate = await _readAccountForDelta(
        firestoreTransaction,
        uid: uid,
        accountId: transaction.accountId,
        delta: _signedDelta(transaction),
      );

      firestoreTransaction.set(docRef, {
        ...transaction.copyWith(userId: uid).toFirestore(),
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
      _applyAccountUpdate(firestoreTransaction, accountUpdate);
    });

    return docRef;
  }

  Future<void> updateTransaction(String id, Map<String, dynamic> data) async {
    final uid = _requireUid();
    final newTransaction = TransactionModel.fromMap(data, fallbackUserId: uid);

    await _firestore.runTransaction((firestoreTransaction) async {
      final docRef = _transactions.doc(id);
      final oldSnapshot = await firestoreTransaction.get(docRef);
      if (!oldSnapshot.exists) {
        throw StateError("Giao dịch không tồn tại");
      }

      final oldTransaction = TransactionModel.fromFirestore(oldSnapshot);
      if (oldTransaction.userId != uid) {
        throw StateError("Bạn không có quyền sửa giao dịch này");
      }

      final oldAccountId = oldTransaction.accountId;
      final newAccountId = newTransaction.accountId;
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
                  _signedDelta(newTransaction) - _signedDelta(oldTransaction),
            )
          : await _readAccountForDelta(
              firestoreTransaction,
              uid: uid,
              accountId: newAccountId,
              delta: _signedDelta(newTransaction),
            );

      final payload = {
        ...newTransaction.copyWith(id: id, userId: uid).toFirestore(),
        "updatedAt": FieldValue.serverTimestamp(),
      };
      if (newTransaction.accountId == null ||
          newTransaction.accountId!.isEmpty) {
        payload["accountId"] = FieldValue.delete();
      }

      _applyAccountUpdate(firestoreTransaction, oldAccountUpdate);
      _applyAccountUpdate(firestoreTransaction, newAccountUpdate);
      firestoreTransaction.update(docRef, payload);
    });
  }

  Future<void> deleteTransaction(String id) async {
    final uid = _requireUid();

    await _firestore.runTransaction((firestoreTransaction) async {
      final docRef = _transactions.doc(id);
      final snapshot = await firestoreTransaction.get(docRef);
      if (!snapshot.exists) return;

      final oldTransaction = TransactionModel.fromFirestore(snapshot);
      if (oldTransaction.userId != uid) {
        throw StateError("Bạn không có quyền xóa giao dịch này");
      }

      final accountUpdate = await _readAccountForDelta(
        firestoreTransaction,
        uid: uid,
        accountId: oldTransaction.accountId,
        delta: -_signedDelta(oldTransaction),
      );
      _applyAccountUpdate(firestoreTransaction, accountUpdate);
      firestoreTransaction.delete(docRef);
    });
  }

  double _signedDelta(TransactionModel transaction) {
    return transaction.isIncome ? transaction.amount : -transaction.amount;
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
