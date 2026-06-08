import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/account_model.dart';
import '../models/bank_extracted_transaction.dart';
import '../services/account_service.dart';
import '../services/transaction_service.dart';
import '../widgets/category_icon_helper.dart';

class BankTransactionReviewScreen extends StatefulWidget {
  final List<BankExtractedTransaction> transactions;
  final List<String> warnings;

  const BankTransactionReviewScreen({
    super.key,
    required this.transactions,
    this.warnings = const [],
  });

  @override
  State<BankTransactionReviewScreen> createState() =>
      _BankTransactionReviewScreenState();
}

class _BankTransactionReviewScreenState
    extends State<BankTransactionReviewScreen> {
  static const Color primaryGreen = Color(0xFF168A36);

  final AccountService accountService = AccountService();
  final TransactionService transactionService = TransactionService();

  final List<_ReviewItem> items = [];
  List<AccountModel> accounts = [];
  List<_BankCategoryOption> categories = [];
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    items.addAll(widget.transactions.map(_ReviewItem.fromExtracted));
    loadData();
  }

  @override
  void dispose() {
    for (final item in items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> loadData() async {
    try {
      await accountService.ensureDefaultAccount();
      final loadedAccounts = await accountService.getAccountsOnce();
      final loadedCategories = await loadCategories();
      if (!mounted) return;

      setState(() {
        accounts = loadedAccounts;
        categories = loadedCategories;
        for (final item in items) {
          item.accountId = loadedAccounts.isEmpty
              ? null
              : loadedAccounts
                    .firstWhere(
                      (account) => account.isDefault,
                      orElse: () => loadedAccounts.first,
                    )
                    .id;
          item.category = chooseInitialCategory(item, loadedCategories);
        }
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<_BankCategoryOption>> loadCategories() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final custom = <_BankCategoryOption>[];
    if (uid != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection("categories")
          .where("userId", isEqualTo: uid)
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data["name"]?.toString().trim();
        if (name == null || name.isEmpty) continue;
        custom.add(
          _BankCategoryOption(
            id: doc.id,
            name: name,
            type: data["type"] == "income" ? "income" : "expense",
            iconName: data["iconName"]?.toString() ?? "category",
            colorValue: getCategoryColor(data["color"]).toARGB32(),
          ),
        );
      }
    }

    final defaults = <_BankCategoryOption>[
      _BankCategoryOption.defaultItem(
        "Ăn uống",
        "expense",
        "restaurant",
        Colors.orange,
      ),
      _BankCategoryOption.defaultItem(
        "Đi lại",
        "expense",
        "directions_bus",
        Colors.deepOrange,
      ),
      _BankCategoryOption.defaultItem(
        "Mua sắm",
        "expense",
        "shopping_cart",
        Colors.blue,
      ),
      _BankCategoryOption.defaultItem(
        "Tiền điện",
        "expense",
        "electrical_services",
        Colors.amber,
      ),
      _BankCategoryOption.defaultItem("Tiền nhà", "expense", "home", Colors.brown),
      _BankCategoryOption.defaultItem("Khác", "expense", "more_horiz", Colors.grey),
      _BankCategoryOption.defaultItem(
        "Tiền lương",
        "income",
        "account_balance_wallet",
        Colors.green,
      ),
      _BankCategoryOption.defaultItem(
        "Thu nhập phụ",
        "income",
        "attach_money",
        Colors.blue,
      ),
      _BankCategoryOption.defaultItem(
        "Tiền thưởng",
        "income",
        "card_giftcard",
        Colors.red,
      ),
      _BankCategoryOption.defaultItem("Khác", "income", "more_horiz", Colors.grey),
    ];

    final merged = <_BankCategoryOption>[];
    final keys = <String>{};
    for (final category in [...custom, ...defaults]) {
      final key = "${category.type}:${category.name}";
      if (keys.add(key)) merged.add(category);
    }
    return merged;
  }

  _BankCategoryOption? chooseInitialCategory(
    _ReviewItem item,
    List<_BankCategoryOption> allCategories,
  ) {
    final sameType = allCategories
        .where((category) => category.type == item.type)
        .toList();
    if (sameType.isEmpty) return null;
    final suggested = item.extracted.suggestedCategory;
    if (suggested != null && suggested.isNotEmpty) {
      for (final category in sameType) {
        if (category.name.toLowerCase() == suggested.toLowerCase()) {
          return category;
        }
      }
    }
    return sameType.firstWhere(
      (category) => category.name == "Khác",
      orElse: () => sameType.first,
    );
  }

  Future<bool> isPossibleDuplicate(_ReviewItem item) async {
    final existing = await transactionService.getTransactionsOnce();
    final amount = double.tryParse(item.amountController.text.trim()) ?? 0;

    return existing.any((transaction) {
      final sameDate = DateUtils.isSameDay(transaction.date, item.date);
      final sameAmount = transaction.amount == amount;
      final sameType = transaction.type == item.type;
      return sameDate && sameAmount && sameType;
    });
  }

  Future<bool> confirmDuplicate() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Có thể trùng giao dịch"),
        content: const Text(
          "Giao dịch này có thể đã tồn tại. Bạn vẫn muốn lưu không?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Vẫn lưu"),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> saveTransactions() async {
    if (isSaving) return;
    setState(() {
      isSaving = true;
    });

    try {
      for (final item in items) {
        final amount = double.tryParse(item.amountController.text.trim()) ?? 0;
        if (amount <= 0 || item.accountId == null || item.category == null) {
          throw StateError(
            "Vui lòng kiểm tra số tiền, tài khoản và danh mục.",
          );
        }

        if (await isPossibleDuplicate(item)) {
          if (!mounted) return;
          final shouldContinue = await confirmDuplicate();
          if (!mounted) return;
          if (!shouldContinue) continue;
        }

        final category = item.category!;
        await transactionService.addTransaction({
          "amount": amount,
          "type": item.type,
          "date": item.date,
          "note": "",
          "accountId": item.accountId,
          "category": category.name,
          "categoryId": category.id,
          "categoryName": category.name,
          "categoryType": category.type,
          "categoryIconName": category.iconName,
          "categoryColorValue": category.colorValue,
          "source": "bank_image_ocr",
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã lưu giao dịch từ ảnh ngân hàng")),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Không thể lưu: $error")));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> pickDate(_ReviewItem item) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: item.date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() {
      item.date = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Xác nhận giao dịch từ ảnh"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.warnings.isNotEmpty)
            Card(
              color: Colors.amber.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(widget.warnings.join("\n")),
              ),
            ),
          for (final item in items) _TransactionReviewCard(
            item: item,
            accounts: accounts,
            categories: categories
                .where((category) => category.type == item.type)
                .toList(),
            onChanged: () => setState(() {}),
            onPickDate: () => pickDate(item),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: isSaving ? null : saveTransactions,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(isSaving ? "Đang lưu..." : "Lưu tất cả giao dịch"),
          ),
        ],
      ),
    );
  }
}

class _TransactionReviewCard extends StatelessWidget {
  final _ReviewItem item;
  final List<AccountModel> accounts;
  final List<_BankCategoryOption> categories;
  final VoidCallback onChanged;
  final VoidCallback onPickDate;

  const _TransactionReviewCard({
    required this.item,
    required this.accounts,
    required this.categories,
    required this.onChanged,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat("dd/MM/yyyy");

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: "expense", label: Text("Chi tiêu")),
                ButtonSegment(value: "income", label: Text("Thu nhập")),
              ],
              selected: {item.type},
              onSelectionChanged: (value) {
                item.type = value.first;
                item.category = null;
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: item.amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Số tiền"),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Ngày giao dịch"),
              subtitle: Text(formatter.format(item.date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: onPickDate,
            ),
            DropdownButtonFormField<String>(
              initialValue: item.accountId,
              decoration: const InputDecoration(labelText: "Tài khoản"),
              items: accounts
                  .where((account) => account.id != null)
                  .map(
                    (account) => DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                item.accountId = value;
                onChanged();
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<_BankCategoryOption>(
              initialValue: categories.contains(item.category)
                  ? item.category
                  : null,
              decoration: const InputDecoration(labelText: "Danh mục"),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(
                            getCategoryIcon(category.iconName),
                            color: Color(category.colorValue),
                          ),
                          const SizedBox(width: 8),
                          Text(category.name),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                item.category = value;
                onChanged();
              },
            ),
            if (item.extracted.confidence < 0.7) ...[
              const SizedBox(height: 8),
              const Text(
                "OCR chưa đọc chắc chắn thông tin. Vui lòng kiểm tra kỹ trước khi lưu.",
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewItem {
  final BankExtractedTransaction extracted;
  final TextEditingController amountController;
  DateTime date;
  String type;
  String? accountId;
  _BankCategoryOption? category;

  _ReviewItem({
    required this.extracted,
    required this.amountController,
    required this.date,
    required this.type,
  });

  factory _ReviewItem.fromExtracted(BankExtractedTransaction transaction) {
    return _ReviewItem(
      extracted: transaction,
      amountController: TextEditingController(
        text: transaction.amount > 0 ? transaction.amount.toStringAsFixed(0) : "",
      ),
      date: transaction.date ?? DateTime.now(),
      type: transaction.type == "income" ? "income" : "expense",
    );
  }

  void dispose() {
    amountController.dispose();
  }
}

class _BankCategoryOption {
  final String? id;
  final String name;
  final String type;
  final String iconName;
  final int colorValue;

  const _BankCategoryOption({
    required this.id,
    required this.name,
    required this.type,
    required this.iconName,
    required this.colorValue,
  });

  factory _BankCategoryOption.defaultItem(
    String name,
    String type,
    String iconName,
    Color color,
  ) {
    return _BankCategoryOption(
      id: null,
      name: name,
      type: type,
      iconName: iconName,
      colorValue: color.toARGB32(),
    );
  }
}
