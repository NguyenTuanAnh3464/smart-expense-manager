import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';
import '../services/transaction_service.dart';
import '../widgets/category_icon_helper.dart';
import '../widgets/transaction_style.dart';
import 'add_transaction_screen.dart';

class TransactionSearchScreen extends StatefulWidget {
  const TransactionSearchScreen({super.key});

  @override
  State<TransactionSearchScreen> createState() =>
      _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends State<TransactionSearchScreen> {
  static const Color primaryGreen = Color(0xFF168A36);

  final TransactionService transactionService = TransactionService();
  final TextEditingController searchController = TextEditingController();

  String query = "";

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String formatMoney(double amount) {
    return "${NumberFormat("#,###", "en_US").format(amount)} VNĐ";
  }

  String formatDate(DateTime date) {
    return DateFormat("dd/MM/yyyy").format(date);
  }

  String typeLabel(String type) {
    switch (TransactionStyle.normalizeType(type)) {
      case "income":
        return "thu thu nhập income tiền thu";
      case "saving":
        return "tiết kiệm tiet kiem saving";
      default:
        return "chi chi tiêu expense tiền chi";
    }
  }

  String removeVietnameseDiacritics(String input) {
    var text = input.toLowerCase();
    const replacements = <String, String>{
      "à": "a",
      "á": "a",
      "ạ": "a",
      "ả": "a",
      "ã": "a",
      "â": "a",
      "ầ": "a",
      "ấ": "a",
      "ậ": "a",
      "ẩ": "a",
      "ẫ": "a",
      "ă": "a",
      "ằ": "a",
      "ắ": "a",
      "ặ": "a",
      "ẳ": "a",
      "ẵ": "a",
      "è": "e",
      "é": "e",
      "ẹ": "e",
      "ẻ": "e",
      "ẽ": "e",
      "ê": "e",
      "ề": "e",
      "ế": "e",
      "ệ": "e",
      "ể": "e",
      "ễ": "e",
      "ì": "i",
      "í": "i",
      "ị": "i",
      "ỉ": "i",
      "ĩ": "i",
      "ò": "o",
      "ó": "o",
      "ọ": "o",
      "ỏ": "o",
      "õ": "o",
      "ô": "o",
      "ồ": "o",
      "ố": "o",
      "ộ": "o",
      "ổ": "o",
      "ỗ": "o",
      "ơ": "o",
      "ờ": "o",
      "ớ": "o",
      "ợ": "o",
      "ở": "o",
      "ỡ": "o",
      "ù": "u",
      "ú": "u",
      "ụ": "u",
      "ủ": "u",
      "ũ": "u",
      "ư": "u",
      "ừ": "u",
      "ứ": "u",
      "ự": "u",
      "ử": "u",
      "ữ": "u",
      "ỳ": "y",
      "ý": "y",
      "ỵ": "y",
      "ỷ": "y",
      "ỹ": "y",
      "đ": "d",
    };

    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text;
  }

  String normalizeText(String value) {
    return removeVietnameseDiacritics(
      value.trim().replaceAll(RegExp(r'\s+'), " "),
    );
  }

  String normalizeNumber(String value) {
    var normalized = value
        .toLowerCase()
        .replaceAll("vnđ", "")
        .replaceAll("vnd", "")
        .replaceAll("đ", "")
        .replaceAll(",", "")
        .replaceAll(".", "")
        .replaceAll(" ", "")
        .trim();

    if (normalized.endsWith("k")) {
      final value = double.tryParse(normalized.substring(0, normalized.length - 1));
      if (value != null) return (value * 1000).round().toString();
    }
    if (normalized.endsWith("tr")) {
      final value = double.tryParse(normalized.substring(0, normalized.length - 2));
      if (value != null) return (value * 1000000).round().toString();
    }
    return normalized;
  }

  DateTime? parseVietnameseDate(String value) {
    final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(value);
    if (match == null) return null;
    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;
    final date = DateTime(year, month, day);
    if (date.day != day || date.month != month || date.year != year) {
      return null;
    }
    return date;
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.day == b.day && a.month == b.month && a.year == b.year;
  }

  bool matchesSearch(TransactionModel transaction, String rawQuery) {
    final q = normalizeText(rawQuery);
    if (q.isEmpty) return true;

    final note = normalizeText(transaction.note);
    final title = normalizeText(transaction.title ?? "");
    final category = normalizeText(transaction.category);
    final categoryName = normalizeText(transaction.categoryName ?? "");
    final type = normalizeText(transaction.type);
    final typeText = normalizeText(typeLabel(transaction.type));
    final source = normalizeText(transaction.source ?? "");
    final rawBankContent = normalizeText(transaction.rawBankContent ?? "");
    final rawBankText = normalizeText(transaction.rawBankText ?? "");
    final accountNumber = normalizeText(transaction.bankAccountNumber ?? "");
    final dateText = normalizeText(formatDate(transaction.date));
    final createdAtText = transaction.createdAt == null
        ? ""
        : normalizeText(formatDate(transaction.createdAt!));

    final normalizedQueryNumber = normalizeNumber(q);
    final normalizedAmount = transaction.amount.round().toString();
    final parsedQueryDate = parseVietnameseDate(q);

    return note.contains(q) ||
        title.contains(q) ||
        category.contains(q) ||
        categoryName.contains(q) ||
        type.contains(q) ||
        typeText.contains(q) ||
        source.contains(q) ||
        rawBankContent.contains(q) ||
        rawBankText.contains(q) ||
        accountNumber.contains(q) ||
        dateText.contains(q) ||
        createdAtText.contains(q) ||
        (parsedQueryDate != null &&
            isSameDay(transaction.date, parsedQueryDate)) ||
        (normalizedQueryNumber.isNotEmpty &&
            normalizedAmount.contains(normalizedQueryNumber));
  }

  Future<void> editTransaction(TransactionModel transaction) async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          type: transaction.type,
          transaction: transaction.toFirestore(),
        ),
      ),
    );
    if (!mounted || result == null || transaction.id == null) return;

    try {
      await transactionService.updateTransaction(transaction.id!, result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể sửa giao dịch: $error")),
      );
    }
  }

  IconData transactionIcon(TransactionModel transaction) {
    return getTransactionIconFromData(
      type: transaction.type,
      categoryIconName: transaction.categoryIconName,
    );
  }

  Color transactionColor(TransactionModel transaction) {
    return getTransactionColorFromData(
      type: transaction.type,
      categoryColorValue: transaction.categoryColorValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tìm kiếm"),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: searchController,
              autofocus: true,
              onChanged: (value) {
                setState(() {
                  query = value;
                });
              },
              decoration: InputDecoration(
                hintText: "Tìm theo ghi chú, số tiền, danh mục...",
                prefixIcon: const Icon(Icons.search, color: primaryGreen),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: "Xóa",
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            query = "";
                          });
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: primaryGreen, width: 2),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<TransactionModel>>(
              stream: transactionService.getTransactionsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text("Không thể tải giao dịch: ${snapshot.error}"),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions = snapshot.data!
                    .where((transaction) => matchesSearch(transaction, query))
                    .toList();

                if (query.trim().isEmpty && transactions.isEmpty) {
                  return const Center(child: Text("Chưa có giao dịch nào"));
                }
                if (query.trim().isNotEmpty && transactions.isEmpty) {
                  return const Center(
                    child: Text("Không tìm thấy giao dịch phù hợp"),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final color = transactionColor(transaction);
                    final note = transaction.note.trim().isEmpty
                        ? "Không có ghi chú"
                        : transaction.note.trim();

                    return Card(
                      color: theme.cardColor,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        onTap: () => editTransaction(transaction),
                        leading: Icon(
                          transactionIcon(transaction),
                          color: color,
                          size: 30,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                transaction.category,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              "${TransactionStyle.signFor(transaction.type)}${formatMoney(transaction.amount)}",
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          "$note • ${formatDate(transaction.date)}",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.68,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
