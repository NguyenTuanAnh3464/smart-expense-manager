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
  final String? categoryId;
  final String? categoryName;
  final String? categoryType;
  final String? categoryIconName;
  final int? categoryColorValue;
  final String? goalId;
  final String? source;
  final String? rawBankContent;
  final String? rawBankText;
  final String? bankTransactionTime;
  final String? bankAccountNumber;
  final double? bankFee;
  final double? balanceAfterFromBank;
  final String? bankImageUrl;
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
    this.categoryId,
    this.categoryName,
    this.categoryType,
    this.categoryIconName,
    this.categoryColorValue,
    this.goalId,
    this.source,
    this.rawBankContent,
    this.rawBankText,
    this.bankTransactionTime,
    this.bankAccountNumber,
    this.bankFee,
    this.balanceAfterFromBank,
    this.bankImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  bool get isIncome => normalizeType(type) == "income";

  bool get isExpense => normalizeType(type) == "expense";

  bool get isSaving => normalizeType(type) == "saving";

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
    String? categoryId,
    String? categoryName,
    String? categoryType,
    String? categoryIconName,
    int? categoryColorValue,
    String? goalId,
    String? source,
    String? rawBankContent,
    String? rawBankText,
    String? bankTransactionTime,
    String? bankAccountNumber,
    double? bankFee,
    double? balanceAfterFromBank,
    String? bankImageUrl,
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
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryType: categoryType ?? this.categoryType,
      categoryIconName: categoryIconName ?? this.categoryIconName,
      categoryColorValue: categoryColorValue ?? this.categoryColorValue,
      goalId: goalId ?? this.goalId,
      source: source ?? this.source,
      rawBankContent: rawBankContent ?? this.rawBankContent,
      rawBankText: rawBankText ?? this.rawBankText,
      bankTransactionTime: bankTransactionTime ?? this.bankTransactionTime,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankFee: bankFee ?? this.bankFee,
      balanceAfterFromBank: balanceAfterFromBank ?? this.balanceAfterFromBank,
      bankImageUrl: bankImageUrl ?? this.bankImageUrl,
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
    final note = (data["note"] ?? data["title"] ?? "").toString().trim();
    final title = _parseOptionalString(data["title"]);
    final category = data["category"]?.toString().trim();

    return TransactionModel(
      id: id ?? data["id"]?.toString(),
      userId: data["userId"]?.toString() ?? fallbackUserId,
      category: category?.isNotEmpty == true ? category! : "Khác",
      amount: parseAmount(data["amount"]),
      note: note,
      type: normalizeType(data["type"]?.toString()),
      date: parseDate(data["date"]) ?? DateTime.fromMillisecondsSinceEpoch(0),
      title: title,
      accountId: _parseOptionalString(data["accountId"]),
      categoryId: _parseOptionalString(data["categoryId"]),
      categoryName: _parseOptionalString(data["categoryName"]),
      categoryType: _parseOptionalString(data["categoryType"]),
      categoryIconName: _parseOptionalString(data["categoryIconName"]),
      categoryColorValue: _parseOptionalInt(
        data["categoryColorValue"] ?? data["categoryColorHex"],
      ),
      goalId: _parseOptionalString(data["goalId"]),
      source: _parseOptionalString(data["source"]),
      rawBankContent: _parseOptionalString(data["rawBankContent"]),
      rawBankText: _parseOptionalString(data["rawBankText"]),
      bankTransactionTime: _parseOptionalString(data["bankTransactionTime"]),
      bankAccountNumber: _parseOptionalString(data["bankAccountNumber"]),
      bankFee: _parseOptionalDouble(data["bankFee"]),
      balanceAfterFromBank: _parseOptionalDouble(data["balanceAfterFromBank"]),
      bankImageUrl: _parseOptionalString(data["bankImageUrl"]),
      createdAt: parseDate(data["createdAt"]),
      updatedAt: parseDate(data["updatedAt"]),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (userId != null) "userId": userId,
      "category": category,
      if (categoryId != null && categoryId!.isNotEmpty)
        "categoryId": categoryId,
      if (categoryName != null && categoryName!.isNotEmpty)
        "categoryName": categoryName,
      if (categoryType != null && categoryType!.isNotEmpty)
        "categoryType": categoryType,
      if (categoryIconName != null && categoryIconName!.isNotEmpty)
        "categoryIconName": categoryIconName,
      if (categoryColorValue != null) "categoryColorValue": categoryColorValue,
      "amount": amount,
      "note": note,
      "type": normalizeType(type),
      "date": Timestamp.fromDate(date),
      if (title != null) "title": title,
      if (accountId != null && accountId!.isNotEmpty) "accountId": accountId,
      if (goalId != null && goalId!.isNotEmpty) "goalId": goalId,
      if (source != null && source!.isNotEmpty) "source": source,
      if (rawBankContent != null && rawBankContent!.isNotEmpty)
        "rawBankContent": rawBankContent,
      if (rawBankText != null && rawBankText!.isNotEmpty)
        "rawBankText": rawBankText,
      if (bankTransactionTime != null && bankTransactionTime!.isNotEmpty)
        "bankTransactionTime": bankTransactionTime,
      if (bankAccountNumber != null && bankAccountNumber!.isNotEmpty)
        "bankAccountNumber": bankAccountNumber,
      if (bankFee != null) "bankFee": bankFee,
      if (balanceAfterFromBank != null)
        "balanceAfterFromBank": balanceAfterFromBank,
      if (bankImageUrl != null && bankImageUrl!.isNotEmpty)
        "bankImageUrl": bankImageUrl,
    };
  }

  static double parseAmount(dynamic value) {
    if (value is num) return value.toDouble().abs();
    if (value is String) {
      final normalized = value.replaceAll(",", "").replaceAll("đ", "").trim();
      return (double.tryParse(normalized) ?? 0).abs();
    }
    return 0;
  }

  static String? _parseOptionalString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static int? _parseOptionalInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final text = value.trim();
      final decimal = int.tryParse(text);
      if (decimal != null) return decimal;
      final normalized = text
          .replaceFirst("#", "")
          .replaceFirst("0x", "")
          .replaceFirst("0X", "");
      final hex = int.tryParse(normalized, radix: 16);
      if (hex == null) return null;
      return normalized.length <= 6 ? 0xFF000000 | hex : hex;
    }
    return null;
  }

  static double? _parseOptionalDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(",", "").trim());
    }
    return null;
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
    if (raw == "saving" ||
        raw == "transfer_to_saving" ||
        raw == "budget_to_saving") {
      return "saving";
    }
    if (raw.contains("income") || raw == "thu" || raw.contains("tiền thu")) {
      return "income";
    }
    if (raw.contains("expense") || raw == "chi" || raw.contains("tiền chi")) {
      return "expense";
    }
    return "expense";
  }
}
