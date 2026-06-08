import '../models/account_model.dart';
import '../models/transaction_model.dart';

class AIService {
  static const String _backendUrl = String.fromEnvironment("AI_BACKEND_URL");
  static const String notConfiguredMessage = "Tính năng AI chưa được cấu hình.";
  static const int _maxTransactions = 100;
  static const int _recentDays = 30;

  bool get isConfigured => _backendUrl.trim().isNotEmpty;

  Future<String> sendChatMessage({
    required String message,
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    List<Map<String, dynamic>> budgets = const [],
  }) async {
    try {
      final cleanedMessage = _shorten(message, 240);
      if (cleanedMessage.isEmpty) {
        return "Bạn hãy nhập câu hỏi trước nhé.";
      }

      final scopedTransactions = _recentTransactions(transactions);
      if (scopedTransactions.isEmpty) {
        return "Bạn chưa có đủ dữ liệu giao dịch để phân tích.";
      }

      final prompt = _buildChatPrompt(
        message: cleanedMessage,
        transactions: scopedTransactions,
        accounts: accounts,
        budgets: budgets,
      );

      if (!isConfigured) {
        return "$notConfiguredMessage\n\n${_buildLocalAnswer(cleanedMessage, scopedTransactions, accounts, budgets)}";
      }

      return _callBackendPlaceholder(prompt);
    } catch (_) {
      return "AI tạm thời không phản hồi. Bạn vẫn có thể tiếp tục sử dụng app bình thường.";
    }
  }

  Future<String> generateFinancialInsight({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    List<Map<String, dynamic>> budgets = const [],
  }) async {
    try {
      final scopedTransactions = _recentTransactions(transactions);
      if (scopedTransactions.isEmpty) {
        return "Bạn chưa có đủ dữ liệu giao dịch để phân tích.";
      }

      final prompt = _buildInsightPrompt(
        transactions: scopedTransactions,
        accounts: accounts,
        budgets: budgets,
      );

      if (!isConfigured) {
        return "$notConfiguredMessage\n\n${_buildLocalInsight(scopedTransactions, accounts, budgets)}";
      }

      return _callBackendPlaceholder(prompt);
    } catch (_) {
      return "Không thể tạo phân tích AI lúc này. Dữ liệu trong app vẫn an toàn và không bị thay đổi.";
    }
  }

  Future<String?> suggestCategory({
    required String note,
    required double amount,
    required String type,
  }) async {
    try {
      final cleanedNote = _shorten(note, 80);
      if (cleanedNote.isEmpty || amount < 0) return null;

      final localSuggestion = _localCategorySuggestion(
        note: cleanedNote,
        type: TransactionModel.normalizeType(type),
      );

      if (!isConfigured) return localSuggestion;

      // TODO: Send only note, amount, and type to a trusted backend such as
      // Firebase Cloud Functions. Never put an AI API key in Flutter source.
      return localSuggestion;
    } catch (_) {
      return null;
    }
  }

  String _callBackendPlaceholder(String prompt) {
    final _ = prompt;
    return "Backend AI đã được cấu hình URL nhưng phần gọi backend chưa được triển khai. Hãy kết nối Firebase Cloud Functions để gọi AI an toàn.";
  }

  List<TransactionModel> _recentTransactions(
    List<TransactionModel> transactions,
  ) {
    final sorted = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    final cutoff = DateTime.now().subtract(const Duration(days: _recentDays));
    final recent = sorted.where((item) => item.date.isAfter(cutoff)).toList();
    final scoped = recent.isEmpty ? sorted : recent;
    return scoped.take(_maxTransactions).toList();
  }

  String _buildChatPrompt({
    required String message,
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required List<Map<String, dynamic>> budgets,
  }) {
    return [
      "Bạn là trợ lý tài chính cá nhân. Trả lời bằng tiếng Việt, ngắn gọn, dễ hiểu.",
      "Không đưa lời khuyên đầu tư rủi ro hoặc cam kết chắc chắn.",
      "Câu hỏi: $message",
      "Giao dịch: ${_sanitizeTransactions(transactions)}",
      "Tài khoản: ${_sanitizeAccounts(accounts)}",
      "Ngân sách: ${_sanitizeBudgets(budgets)}",
    ].join("\n");
  }

  String _buildInsightPrompt({
    required List<TransactionModel> transactions,
    required List<AccountModel> accounts,
    required List<Map<String, dynamic>> budgets,
  }) {
    return [
      "Bạn là trợ lý tài chính cá nhân. Hãy phân tích dữ liệu chi tiêu sau bằng tiếng Việt.",
      "Trả lời ngắn gọn, dễ hiểu, không đưa lời khuyên đầu tư rủi ro.",
      "Tập trung vào tổng thu, tổng chi, danh mục chi nhiều nhất, xu hướng chi tiêu và gợi ý tiết kiệm.",
      "Giao dịch: ${_sanitizeTransactions(transactions)}",
      "Tài khoản: ${_sanitizeAccounts(accounts)}",
      "Ngân sách: ${_sanitizeBudgets(budgets)}",
    ].join("\n");
  }

  String _buildLocalAnswer(
    String message,
    List<TransactionModel> transactions,
    List<AccountModel> accounts,
    List<Map<String, dynamic>> budgets,
  ) {
    final lower = message.toLowerCase();
    if (lower.contains("nhiều nhất") ||
        lower.contains("giảm khoản") ||
        lower.contains("giảm khoản nào")) {
      return _topCategoryInsight(transactions);
    }
    if (lower.contains("tiết kiệm") || lower.contains("quá nhiều")) {
      return _savingInsight(transactions, budgets);
    }
    return _buildLocalInsight(transactions, accounts, budgets);
  }

  String _buildLocalInsight(
    List<TransactionModel> transactions,
    List<AccountModel> accounts,
    List<Map<String, dynamic>> budgets,
  ) {
    final stats = _calculateStats(transactions);
    final accountBalance = accounts.fold<double>(
      0,
      (total, account) => total + account.balance,
    );
    final topCategory = _topExpenseCategory(stats.expenseByCategory);
    final budgetHint = _budgetHint(stats.expenseByCategory, budgets);

    return [
      "Phân tích cục bộ từ dữ liệu gần đây:",
      "- Tổng thu: ${_money(stats.totalIncome)}.",
      "- Tổng chi: ${_money(stats.totalExpense)}.",
      "- Thu chi ròng: ${_money(stats.balance)}.",
      "- Số dư các tài khoản: ${_money(accountBalance)}.",
      if (topCategory != null)
        "- Chi nhiều nhất: ${topCategory.key} (${_money(topCategory.value)}).",
      if (budgetHint != null) "- $budgetHint",
      "- Gợi ý tham khảo: ưu tiên giảm các khoản chi lặp lại và kiểm tra ngân sách trước khi chi lớn.",
      "Gợi ý từ AI chỉ mang tính tham khảo.",
    ].join("\n");
  }

  String _topCategoryInsight(List<TransactionModel> transactions) {
    final stats = _calculateStats(transactions);
    final topCategory = _topExpenseCategory(stats.expenseByCategory);
    if (topCategory == null) {
      return "Chưa có khoản chi nào đủ rõ để xác định danh mục tiêu nhiều nhất.";
    }
    return [
      "Phân tích cục bộ:",
      "Bạn đang chi nhiều nhất vào ${topCategory.key}: ${_money(topCategory.value)}.",
      "Gợi ý tham khảo: xem lại các giao dịch trong danh mục này trước khi cắt giảm những khoản cần thiết.",
    ].join("\n");
  }

  String _savingInsight(
    List<TransactionModel> transactions,
    List<Map<String, dynamic>> budgets,
  ) {
    final stats = _calculateStats(transactions);
    final topCategory = _topExpenseCategory(stats.expenseByCategory);
    final suggestions = <String>[
      "Phân tích cục bộ:",
      "Tỷ lệ chi/thu hiện tại: ${stats.totalIncome <= 0 ? "chưa đủ dữ liệu thu nhập" : "${(stats.totalExpense / stats.totalIncome * 100).toStringAsFixed(0)}%"}.",
    ];
    if (topCategory != null) {
      suggestions.add(
        "Khoản nên kiểm tra trước: ${topCategory.key} (${_money(topCategory.value)}).",
      );
    }
    final budgetHint = _budgetHint(stats.expenseByCategory, budgets);
    if (budgetHint != null) suggestions.add(budgetHint);
    suggestions.add(
      "Gợi ý tham khảo: đặt giới hạn nhỏ cho chi tiêu hằng ngày và theo dõi lại sau 7 ngày.",
    );
    return suggestions.join("\n");
  }

  _FinancialStats _calculateStats(List<TransactionModel> transactions) {
    var totalIncome = 0.0;
    var totalExpense = 0.0;
    final expenseByCategory = <String, double>{};

    for (final transaction in transactions) {
      if (transaction.isIncome) {
        totalIncome += transaction.amount;
      } else {
        totalExpense += transaction.amount;
        expenseByCategory.update(
          transaction.category,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      }
    }

    return _FinancialStats(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      expenseByCategory: expenseByCategory,
    );
  }

  MapEntry<String, double>? _topExpenseCategory(
    Map<String, double> expenseByCategory,
  ) {
    if (expenseByCategory.isEmpty) return null;
    final entries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  String? _budgetHint(
    Map<String, double> expenseByCategory,
    List<Map<String, dynamic>> budgets,
  ) {
    for (final budget in budgets) {
      final category = budget["category"]?.toString();
      final amount = budget["amount"];
      if (category == null || amount is! num) continue;
      final spent = expenseByCategory[category] ?? 0;
      if (spent > amount.toDouble()) {
        return "Danh mục $category đang vượt ngân sách khoảng ${_money(spent - amount.toDouble())}.";
      }
    }
    return null;
  }

  List<Map<String, Object?>> _sanitizeTransactions(
    List<TransactionModel> transactions,
  ) {
    return transactions.map((item) {
      return {
        "amount": item.amount,
        "type": TransactionModel.normalizeType(item.type),
        "category": _shorten(item.category, 40),
        "note": _shorten(item.note, 60),
        "date": item.date.toIso8601String().split("T").first,
      };
    }).toList();
  }

  List<Map<String, Object?>> _sanitizeAccounts(List<AccountModel> accounts) {
    return accounts.map((account) {
      return {
        "name": _shorten(account.name, 40),
        "type": account.type,
        "balance": account.balance,
        "currency": account.currency,
      };
    }).toList();
  }

  List<Map<String, Object?>> _sanitizeBudgets(
    List<Map<String, dynamic>> budgets,
  ) {
    return budgets.take(30).map((budget) {
      return {
        "category": _shorten(budget["category"]?.toString() ?? "", 40),
        "amount": budget["amount"],
        "month": budget["month"],
        "year": budget["year"],
        "type": budget["type"],
      };
    }).toList();
  }

  String _localCategorySuggestion({
    required String note,
    required String type,
  }) {
    final lower = note.toLowerCase();
    if (type == "income") {
      if (_containsAny(lower, ["lương", "salary", "payroll"])) {
        return "Tiền lương";
      }
      if (_containsAny(lower, ["thưởng", "bonus"])) return "Tiền thưởng";
      if (_containsAny(lower, ["phụ cấp", "allowance"])) {
        return "Tiền phụ cấp";
      }
      if (_containsAny(lower, ["đầu tư", "lãi", "cổ tức"])) return "Đầu tư";
      return "Thu nhập phụ";
    }

    if (_containsAny(lower, [
      "ăn",
      "cơm",
      "bún",
      "phở",
      "sáng",
      "trưa",
      "tối",
      "cafe",
      "cà phê",
      "trà sữa",
    ])) {
      return "Ăn uống";
    }
    if (_containsAny(lower, ["xăng", "grab", "taxi", "bus", "xe", "đi lại"])) {
      return "Đi lại";
    }
    if (_containsAny(lower, ["áo", "quần", "giày", "váy"])) return "Quần áo";
    if (_containsAny(lower, ["son", "kem", "mỹ phẩm"])) return "Mỹ phẩm";
    if (_containsAny(lower, ["thuốc", "bệnh", "khám", "viện"])) return "Y tế";
    if (_containsAny(lower, ["học", "sách", "khóa", "trường"])) {
      return "Giáo dục";
    }
    if (_containsAny(lower, ["điện", "evn"])) return "Tiền điện";
    if (_containsAny(lower, ["nhà", "trọ", "thuê"])) return "Tiền nhà";
    return "Khác";
  }

  bool _containsAny(String value, List<String> keywords) {
    return keywords.any(value.contains);
  }

  String _shorten(String value, int maxLength) {
    final cleaned = value.trim().replaceAll(RegExp(r"\s+"), " ");
    if (cleaned.length <= maxLength) return cleaned;
    return "${cleaned.substring(0, maxLength)}...";
  }

  String _money(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final positionFromEnd = rounded.length - i;
      buffer.write(rounded[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(".");
      }
    }
    return "${buffer.toString()}đ";
  }
}

class _FinancialStats {
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final Map<String, double> expenseByCategory;

  const _FinancialStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.expenseByCategory,
  });
}
