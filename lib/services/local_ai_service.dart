import '../models/transaction_model.dart';
import 'ai_context_service.dart';

class LocalAIService {
  static const String totalBudgetCategory = "Tổng ngân sách";

  Future<String> answerQuestion({
    required String question,
    required AIFinancialContext context,
  }) async {
    final normalized = _normalize(question);
    if (normalized.trim().isEmpty) {
      return "Bạn hãy nhập câu hỏi trước nhé.";
    }

    if (normalized.contains("tom tat") || normalized.contains("thang nay")) {
      return summarizeCurrentMonth(context);
    }
    if (normalized.contains("tieu nhieu") ||
        normalized.contains("danh muc") ||
        normalized.contains("nhieu nhat")) {
      return topSpendingCategories(context);
    }
    if (normalized.contains("tiet kiem") ||
        normalized.contains("de danh") ||
        normalized.contains("tich luy")) {
      return savingAdvice(context);
    }
    if (normalized.contains("ngan sach")) {
      return analyzeBudgets(context);
    }

    return "Mình hiện chỉ hỗ trợ phân tích chi tiêu, danh mục, tiết kiệm và ngân sách.";
  }

  Future<String> generateFinancialInsight(AIFinancialContext context) async {
    return [
      summarizeCurrentMonth(context),
      "",
      topSpendingCategories(context),
      "",
      savingAdvice(context),
      "",
      analyzeBudgets(context),
    ].join("\n");
  }

  String summarizeCurrentMonth(AIFinancialContext context) {
    final transactions = _currentMonthTransactions(context.transactions);
    if (transactions.isEmpty) {
      return "Bạn chưa có giao dịch nào để phân tích.";
    }

    final stats = _calculateStats(transactions);
    final totalOutflow = stats.totalExpense + stats.totalSavingTransfer;
    final balance = stats.totalIncome - totalOutflow;
    final comment = stats.totalIncome <= 0
        ? "Chưa có dữ liệu thu nhập, nên chưa thể đánh giá tỷ lệ chi tiêu."
        : totalOutflow > stats.totalIncome * 0.7
        ? "Tổng tiền ra đang khá cao so với thu nhập."
        : "Mức tiền ra hiện tại khá ổn.";

    return "Tháng này bạn có tổng thu ${_money(stats.totalIncome)}, chi tiêu sinh hoạt ${_money(stats.totalExpense)} "
        "và tiền chuyển tiết kiệm ${_money(stats.totalSavingTransfer)}. "
        "Bạn ${balance >= 0 ? "còn dư" : "đang âm"} ${_money(balance.abs())}. "
        "Có ${transactions.length} giao dịch trong tháng. $comment";
  }

  String topSpendingCategories(AIFinancialContext context) {
    final transactions = _currentMonthTransactions(context.transactions);
    if (transactions.isEmpty) {
      return "Bạn chưa có giao dịch nào để phân tích.";
    }

    final stats = _calculateStats(transactions);
    final entries = stats.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return "Tháng này bạn chưa có khoản chi nào.";
    }

    final top = entries.take(3).toList();
    final lines = <String>["Bạn tiêu nhiều nhất vào:"];
    for (var i = 0; i < top.length; i++) {
      lines.add("${i + 1}. ${top[i].key}: ${_money(top[i].value)}");
    }
    lines.add(
      "Danh mục ${top.first.key} đang chiếm phần lớn chi tiêu tháng này.",
    );
    return lines.join("\n");
  }

  String savingAdvice(AIFinancialContext context) {
    final transactions = _currentMonthTransactions(context.transactions);
    if (transactions.isEmpty) {
      return "Bạn chưa có giao dịch nào để phân tích.";
    }

    final stats = _calculateStats(transactions);
    if (stats.totalIncome <= 0) {
      return "Chưa có dữ liệu thu nhập, nên chưa thể đánh giá tỷ lệ chi tiêu.";
    }

    final balance =
        stats.totalIncome - stats.totalExpense - stats.totalSavingTransfer;
    final topCategory = _topExpenseCategory(stats.expenseByCategory);
    final suggestions = <String>[];
    final ratio =
        (stats.totalExpense + stats.totalSavingTransfer) / stats.totalIncome;

    if (ratio > 0.7) {
      suggestions.add(
        "Tổng chi tiêu sinh hoạt và tiền chuyển tiết kiệm đang vượt 70% thu nhập, bạn nên kiểm tra lại các khoản tiền ra lớn.",
      );
    } else if (ratio < 0.5) {
      suggestions.add(
        "Bạn đang giữ chi tiêu sinh hoạt và tiền chuyển tiết kiệm dưới 50% thu nhập, đây là tín hiệu tốt.",
      );
      if (balance > 0) {
        suggestions.add(
          "Bạn có thể chuyển một phần ${_money(balance)} còn dư vào mục tiêu tiết kiệm.",
        );
      }
    } else {
      suggestions.add(
        "Tỷ lệ chi tiêu đang ở mức trung bình, vẫn còn dư địa để tiết kiệm thêm.",
      );
    }

    if (topCategory != null) {
      suggestions.add(
        "Bạn có thể tiết kiệm thêm bằng cách giảm khoảng 10% chi tiêu ở danh mục ${topCategory.key}, tương đương khoảng ${_money(topCategory.value * 0.1)}.",
      );
    }

    if (context.savingGoals.isNotEmpty && balance > 0) {
      final goal = context.savingGoals.first;
      final missing = goal.targetAmount - goal.currentAmount;
      suggestions.add(
        "Mục tiêu \"${goal.title}\" còn thiếu ${_money(missing > 0 ? missing : 0)}.",
      );
    }

    return suggestions.join("\n");
  }

  String analyzeBudgets(AIFinancialContext context) {
    final budgets = context.budgets;
    if (budgets.isEmpty) {
      return "Bạn chưa thiết lập ngân sách.";
    }

    final transactions = _currentMonthTransactions(context.transactions);
    final stats = _calculateStats(transactions);
    final lines = <String>["Phân tích ngân sách tháng này:"];

    for (final budget in budgets) {
      final category = budget["category"]?.toString().trim();
      final budgetAmount = _parseAmount(
        budget["budgetAmount"] ?? budget["amount"] ?? budget["limit"],
      );
      if (category == null || category.isEmpty || budgetAmount <= 0) continue;

      final spent = category == totalBudgetCategory
          ? _totalBudgetUsed(stats, budgets)
          : (stats.expenseByCategory[category] ?? 0) +
                (stats.savingTransferByCategory[category] ?? 0);
      final remaining = budgetAmount - spent;
      final progress = budgetAmount <= 0 ? 0 : spent / budgetAmount * 100;
      final status = progress >= 100
          ? "đã vượt ngân sách"
          : progress >= 80
              ? "sắp vượt ngân sách"
              : "vẫn đang trong mức an toàn";
      lines.add(
        "- $category: đã dùng ${progress.clamp(0, double.infinity).toStringAsFixed(0)}%, gồm chi tiêu sinh hoạt và tiền chuyển tiết kiệm nếu có trừ ngân sách; còn lại ${_money(remaining > 0 ? remaining : 0)}. Bạn $status.",
      );
    }

    if (lines.length == 1) {
      return "Bạn chưa thiết lập ngân sách.";
    }
    return lines.join("\n");
  }

  List<TransactionModel> _currentMonthTransactions(
    List<TransactionModel> transactions,
  ) {
    final now = DateTime.now();
    return transactions
        .where((item) => item.date.month == now.month && item.date.year == now.year)
        .toList();
  }

  _LocalStats _calculateStats(List<TransactionModel> transactions) {
    var totalIncome = 0.0;
    var totalExpense = 0.0;
    var totalSavingTransfer = 0.0;
    final expenseByCategory = <String, double>{};
    final savingTransferByCategory = <String, double>{};

    for (final transaction in transactions) {
      final type = TransactionModel.normalizeType(transaction.type);
      if (type == "income") {
        totalIncome += transaction.amount;
      } else if (type == "expense") {
        totalExpense += transaction.amount;
        final category = transaction.categoryName?.trim().isNotEmpty == true
            ? transaction.categoryName!.trim()
            : transaction.category;
        expenseByCategory.update(
          category,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
      } else if (type == "saving") {
        totalSavingTransfer += transaction.amount;
        final sourceCategory = transaction.sourceBudgetCategory;
        if (sourceCategory != null &&
            sourceCategory.isNotEmpty &&
            transaction.sourceBudgetMonth == transaction.date.month &&
            transaction.sourceBudgetYear == transaction.date.year) {
          savingTransferByCategory.update(
            sourceCategory,
            (value) => value + transaction.amount,
            ifAbsent: () => transaction.amount,
          );
        } else if (sourceCategory != null && sourceCategory.isNotEmpty) {
          final now = DateTime.now();
          if (transaction.sourceBudgetMonth == now.month &&
              transaction.sourceBudgetYear == now.year) {
            savingTransferByCategory.update(
              sourceCategory,
              (value) => value + transaction.amount,
              ifAbsent: () => transaction.amount,
            );
          }
        }
      }
    }

    return _LocalStats(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      totalSavingTransfer: totalSavingTransfer,
      expenseByCategory: expenseByCategory,
      savingTransferByCategory: savingTransferByCategory,
    );
  }

  double _totalBudgetUsed(
    _LocalStats stats,
    List<Map<String, dynamic>> budgets,
  ) {
    final includeUnbudgeted = budgets.isEmpty
        ? true
        : budgets.first["includeUnbudgetedExpenses"] != false;
    final totalSavingTransfer = stats.savingTransferByCategory.values
        .fold<double>(0, (total, amount) => total + amount);
    if (includeUnbudgeted) {
      return stats.totalExpense + totalSavingTransfer;
    }

    final budgetedCategories = budgets
        .where((budget) => budget["type"]?.toString() != "total")
        .map((budget) => budget["category"]?.toString())
        .whereType<String>()
        .toSet();
    final budgetedExpense = stats.expenseByCategory.entries.fold<double>(
      0,
      (total, entry) =>
          budgetedCategories.contains(entry.key) ? total + entry.value : total,
    );
    return budgetedExpense + totalSavingTransfer;
  }

  MapEntry<String, double>? _topExpenseCategory(
    Map<String, double> expenseByCategory,
  ) {
    if (expenseByCategory.isEmpty) return null;
    final entries = expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first;
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(",", "").trim()) ?? 0;
    }
    return 0;
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
    return "$bufferđ";
  }

  String _normalize(String value) {
    var text = value.toLowerCase().trim();
    const chars = {
      "à": "a", "á": "a", "ạ": "a", "ả": "a", "ã": "a",
      "â": "a", "ầ": "a", "ấ": "a", "ậ": "a", "ẩ": "a", "ẫ": "a",
      "ă": "a", "ằ": "a", "ắ": "a", "ặ": "a", "ẳ": "a", "ẵ": "a",
      "è": "e", "é": "e", "ẹ": "e", "ẻ": "e", "ẽ": "e",
      "ê": "e", "ề": "e", "ế": "e", "ệ": "e", "ể": "e", "ễ": "e",
      "ì": "i", "í": "i", "ị": "i", "ỉ": "i", "ĩ": "i",
      "ò": "o", "ó": "o", "ọ": "o", "ỏ": "o", "õ": "o",
      "ô": "o", "ồ": "o", "ố": "o", "ộ": "o", "ổ": "o", "ỗ": "o",
      "ơ": "o", "ờ": "o", "ớ": "o", "ợ": "o", "ở": "o", "ỡ": "o",
      "ù": "u", "ú": "u", "ụ": "u", "ủ": "u", "ũ": "u",
      "ư": "u", "ừ": "u", "ứ": "u", "ự": "u", "ử": "u", "ữ": "u",
      "ỳ": "y", "ý": "y", "ỵ": "y", "ỷ": "y", "ỹ": "y",
      "đ": "d",
    };
    chars.forEach((key, value) {
      text = text.replaceAll(key, value);
    });
    return text.replaceAll(RegExp(r"\s+"), " ");
  }
}

class _LocalStats {
  final double totalIncome;
  final double totalExpense;
  final double totalSavingTransfer;
  final Map<String, double> expenseByCategory;
  final Map<String, double> savingTransferByCategory;

  const _LocalStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSavingTransfer,
    required this.expenseByCategory,
    required this.savingTransferByCategory,
  });
}
