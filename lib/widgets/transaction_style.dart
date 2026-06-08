import 'package:flutter/material.dart';

class TransactionStyle {
  static const Color incomeColor = Colors.green;
  static const Color expenseColor = Colors.redAccent;
  static const Color savingColor = Colors.blue;

  static String normalizeType(Object? value) {
    final raw = value?.toString().trim().toLowerCase() ?? "";
    if (raw == "saving" ||
        raw == "transfer_to_saving" ||
        raw == "budget_to_saving") {
      return "saving";
    }
    if (raw == "income" || raw.contains("income")) return "income";
    return "expense";
  }

  static IconData iconFor(Object? type, {String? category}) {
    switch (normalizeType(type)) {
      case "income":
        return Icons.account_balance_wallet;
      case "saving":
        return Icons.savings;
      default:
        return Icons.shopping_bag;
    }
  }

  static Color colorFor(Object? type) {
    switch (normalizeType(type)) {
      case "income":
        return incomeColor;
      case "saving":
        return savingColor;
      default:
        return expenseColor;
    }
  }

  static String signFor(Object? type) {
    return normalizeType(type) == "income" ? "+" : "-";
  }
}
