import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String? id;
  final String? userId;
  final String category;
  final double amount;
  final String note;
  final String type;
  final DateTime date;
  final String? title;
  final String? accountId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TransactionModel({
    this.id,
    this.userId,
    required this.category,
    required this.amount,
    required this.note,
    required this.type,
    required this.date,
    this.title,
    this.accountId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isIncome => normalizeType(type) == "income";

  bool get isExpense => normalizeType(type) == "expense";

  TransactionModel copyWith({
    String? id,
    String? userId,
    String? category,
    double? amount,
    String? note,
    String? type,
    DateTime? date,
    String? title,
    String? accountId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      type: type ?? this.type,
      date: date ?? this.date,
      title: title ?? this.title,
      accountId: accountId ?? this.accountId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TransactionModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return TransactionModel.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory TransactionModel.fromMap(
    Map<String, dynamic> data, {
    String? id,
    String? fallbackUserId,
  }) {
    final note = (data["note"] ?? data["title"] ?? "").toString();
    final title = data["title"]?.toString();

    return TransactionModel(
      id: id ?? data["id"]?.toString(),
      userId: data["userId"]?.toString() ?? fallbackUserId,
      category: data["category"]?.toString().trim().isNotEmpty == true
          ? data["category"].toString()
          : "Khác",
      amount: parseAmount(data["amount"]),
      note: note,
      type: normalizeType(data["type"]?.toString()),
      date: parseDate(data["date"]) ?? DateTime.now(),
      title: title,
      accountId: _parseOptionalString(data["accountId"]),
      createdAt: parseDate(data["createdAt"]),
      updatedAt: parseDate(data["updatedAt"]),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (userId != null) "userId": userId,
      "category": category,
      "amount": amount,
      "note": note,
      "type": normalizeType(type),
      "date": Timestamp.fromDate(date),
      if (title != null) "title": title,
      if (accountId != null && accountId!.isNotEmpty) "accountId": accountId,
    };
  }

  static double parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(",", "").replaceAll("đ", "").trim();
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }

  static String? _parseOptionalString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static DateTime? parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static String normalizeType(String? value) {
    final raw = (value ?? "").trim().toLowerCase();
    if (raw.contains("income") || raw == "thu" || raw.contains("tiền thu")) {
      return "income";
    }
    if (raw.contains("expense") || raw == "chi" || raw.contains("tiền chi")) {
      return "expense";
    }
    return "expense";
  }
}
