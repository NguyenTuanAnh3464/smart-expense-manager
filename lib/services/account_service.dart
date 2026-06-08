import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/account_model.dart';

class AccountService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AccountService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _accounts {
    return _firestore.collection("accounts");
  }

  CollectionReference<Map<String, dynamic>> get _transactions {
    return _firestore.collection("transactions");
  }

  Stream<List<AccountModel>> getAccountsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _accounts.where("userId", isEqualTo: uid).snapshots().map((
      snapshot,
    ) {
      final accounts = snapshot.docs
          .map(AccountModel.fromFirestore)
          .where((item) => item.userId == uid)
          .toList();
      _sortAccounts(accounts);
      return accounts;
    });
  }

  Future<List<AccountModel>> getAccountsOnce() async {
    final uid = _uid;
    if (uid == null) return [];

    final snapshot = await _accounts.where("userId", isEqualTo: uid).get();
    final accounts = snapshot.docs
        .map(AccountModel.fromFirestore)
        .where((item) => item.userId == uid)
        .toList();
    _sortAccounts(accounts);
    return accounts;
  }

  Future<AccountModel?> getDefaultAccount() async {
    final accounts = await getAccountsOnce();
    if (accounts.isEmpty) return null;
    return accounts.firstWhere(
      (account) => account.isDefault,
      orElse: () => accounts.first,
    );
  }

  Future<AccountModel> ensureDefaultAccount() async {
    final uid = _requireUid();
    final accounts = await getAccountsOnce();
    if (accounts.isNotEmpty) {
      return accounts.firstWhere(
        (account) => account.isDefault,
        orElse: () => accounts.first,
      );
    }

    final doc = await _accounts.add({
      "userId": uid,
      "name": "Tiền mặt",
      "type": "cash",
      "balance": 0,
      "currency": "VND",
      "isDefault": true,
      "icon": "payments",
      "color": 0xFF168A36,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    return AccountModel(
      id: doc.id,
      userId: uid,
      name: "Tiền mặt",
      type: "cash",
      balance: 0,
      currency: "VND",
      isDefault: true,
      icon: "payments",
      color: 0xFF168A36,
      createdAt: DateTime.now(),
    );
  }

  Future<void> addAccount(AccountModel account) async {
    final uid = _requireUid();
    final existingAccounts = await getAccountsOnce();
    final shouldBeDefault = account.isDefault || existingAccounts.isEmpty;

    await _firestore.runTransaction((transaction) async {
      if (shouldBeDefault) {
        await _clearDefaultInTransaction(transaction, uid);
      }

      final doc = _accounts.doc();
      transaction.set(doc, {
        ...account.copyWith(userId: uid, isDefault: shouldBeDefault).toMap(),
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateAccount(AccountModel account) async {
    final uid = _requireUid();
    final id = account.id;
    if (id == null) return;

    await _firestore.runTransaction((transaction) async {
      final doc = _accounts.doc(id);
      final snapshot = await transaction.get(doc);
      if (!snapshot.exists) {
        throw StateError("Tài khoản không tồn tại");
      }
      final current = AccountModel.fromFirestore(snapshot);
      if (current.userId != uid) {
        throw StateError("Bạn không có quyền sửa tài khoản này");
      }

      if (account.isDefault) {
        await _clearDefaultInTransaction(transaction, uid);
      }

      transaction.update(doc, {
        ...account.copyWith(userId: uid).toMap(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setDefaultAccount(String accountId) async {
    final uid = _requireUid();

    await _firestore.runTransaction((transaction) async {
      final targetRef = _accounts.doc(accountId);
      final targetSnapshot = await transaction.get(targetRef);
      if (!targetSnapshot.exists) {
        throw StateError("Tài khoản không tồn tại");
      }
      final target = AccountModel.fromFirestore(targetSnapshot);
      if (target.userId != uid) {
        throw StateError("Bạn không có quyền sửa tài khoản này");
      }

      await _clearDefaultInTransaction(transaction, uid);
      transaction.update(targetRef, {
        "isDefault": true,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> setDefault(String accountId) => setDefaultAccount(accountId);

  Future<void> deleteAccount(String accountId) async {
    final uid = _requireUid();

    final usageSnapshot = await _transactions
        .where("userId", isEqualTo: uid)
        .where("accountId", isEqualTo: accountId)
        .limit(1)
        .get();
    if (usageSnapshot.docs.isNotEmpty) {
      throw StateError("Không thể xóa tài khoản đã có giao dịch");
    }

    await _firestore.runTransaction((transaction) async {
      final doc = _accounts.doc(accountId);
      final snapshot = await transaction.get(doc);
      if (!snapshot.exists) return;
      final account = AccountModel.fromFirestore(snapshot);
      if (account.userId != uid) {
        throw StateError("Bạn không có quyền xóa tài khoản này");
      }
      transaction.delete(doc);
    });
  }

  Future<void> _clearDefaultInTransaction(
    Transaction transaction,
    String uid,
  ) async {
    final snapshot = await _accounts.where("userId", isEqualTo: uid).get();
    for (final doc in snapshot.docs) {
      transaction.update(doc.reference, {
        "isDefault": false,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }
  }

  void _sortAccounts(List<AccountModel> accounts) {
    accounts.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      final createdA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final createdB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return createdA.compareTo(createdB);
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
