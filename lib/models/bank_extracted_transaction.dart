class BankExtractedTransaction {
  final DateTime? date;
  final String? time;
  final String? accountNumber;
  final double amount;
  final double? fee;
  final double? balanceAfter;
  final String content;
  final String currency;
  final String type;
  final double confidence;
  final String rawText;
  final String? suggestedCategory;
  final String? imageUrl;

  const BankExtractedTransaction({
    required this.date,
    required this.amount,
    required this.content,
    required this.currency,
    required this.type,
    required this.confidence,
    this.time,
    this.accountNumber,
    this.fee,
    this.balanceAfter,
    this.rawText = "",
    this.suggestedCategory,
    this.imageUrl,
  });

  factory BankExtractedTransaction.fromMap(Map<String, dynamic> data) {
    final content = data["content"]?.toString().trim() ?? "";
    final type = _normalizeType(data["type"]?.toString());

    return BankExtractedTransaction(
      date: _parseDate(data["date"]),
      time: data["time"]?.toString().trim(),
      accountNumber: data["accountNumber"]?.toString().trim(),
      amount: _parseAmount(data["amount"]),
      fee: _parseNullableAmount(data["fee"]),
      balanceAfter: _parseNullableAmount(data["balanceAfter"]),
      content: content,
      currency: data["currency"]?.toString().trim().isNotEmpty == true
          ? data["currency"].toString().trim()
          : "VND",
      type: type,
      confidence: _parseConfidence(data["confidence"]),
      rawText: data["rawText"]?.toString() ?? "",
      suggestedCategory:
          data["suggestedCategory"]?.toString().trim().isNotEmpty == true
          ? data["suggestedCategory"].toString().trim()
          : suggestCategory(content: content, type: type),
      imageUrl: data["imageUrl"]?.toString().trim(),
    );
  }

  static String suggestCategory({
    required String content,
    required String type,
  }) {
    final text = content.toLowerCase();
    if (type == "income") {
      if (_containsAny(text, ["lương", "luong", "salary", "payroll"])) {
        return "Tiền lương";
      }
      return "Thu nhập phụ";
    }
    if (_containsAny(text, ["shopee", "shopeepay", "lazada", "tiki"])) {
      return "Mua sắm";
    }
    if (_containsAny(text, ["grab", "taxi", "xăng", "xang", "bus"])) {
      return "Đi lại";
    }
    if (_containsAny(text, ["cafe", "coffee", "trà sữa", "tra sua", "food"])) {
      return "Ăn uống";
    }
    if (_containsAny(text, ["evn", "điện", "dien"])) return "Tiền điện";
    if (_containsAny(text, ["nhà", "nha", "thuê", "thue"])) return "Tiền nhà";
    return "Khác";
  }

  static bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  static String _normalizeType(String? value) {
    final raw = (value ?? "").trim().toLowerCase();
    if (raw == "income" || raw.contains("thu") || raw.contains("+")) {
      return "income";
    }
    if (raw == "expense" || raw.contains("chi") || raw.contains("-")) {
      return "expense";
    }
    return "expense";
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      final iso = DateTime.tryParse(value);
      if (iso != null) return iso;
      final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value);
      if (match != null) {
        final day = int.tryParse(match.group(1)!);
        final month = int.tryParse(match.group(2)!);
        final year = int.tryParse(match.group(3)!);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }
    return null;
  }

  static double _parseAmount(dynamic value) {
    return _parseNullableAmount(value) ?? 0;
  }

  static double? _parseNullableAmount(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble().abs();
    if (value is String) {
      final normalized = value
          .replaceAll(",", "")
          .replaceAll(".", "")
          .replaceAll("đ", "")
          .replaceAll("VND", "")
          .replaceAll("vnd", "")
          .trim();
      return double.tryParse(normalized)?.abs();
    }
    return null;
  }

  static double _parseConfidence(dynamic value) {
    if (value is num) return value.toDouble().clamp(0, 1);
    if (value is String) return (double.tryParse(value) ?? 0).clamp(0, 1);
    return 0;
  }
}

class BankImageAnalysisResult {
  final bool success;
  final List<BankExtractedTransaction> transactions;
  final List<String> warnings;
  final String? message;

  const BankImageAnalysisResult({
    required this.success,
    required this.transactions,
    required this.warnings,
    this.message,
  });

  factory BankImageAnalysisResult.fromMap(Map<String, dynamic> data) {
    final rawTransactions = data["transactions"];
    return BankImageAnalysisResult(
      success: data["success"] == true,
      transactions: rawTransactions is List
          ? rawTransactions
                .whereType<Map>()
                .map(
                  (item) => BankExtractedTransaction.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      warnings: data["warnings"] is List
          ? (data["warnings"] as List).map((item) => item.toString()).toList()
          : const [],
      message: data["message"]?.toString(),
    );
  }
}
