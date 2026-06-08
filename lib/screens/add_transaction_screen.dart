import 'package:flutter/material.dart';

import '../models/account_model.dart';
import '../services/ai_service.dart';
import '../services/account_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final String type;
  final Map<String, dynamic>? transaction;
  final DateTime? initialDate;

  const AddTransactionScreen({
    super.key,
    required this.type,
    this.transaction,
    this.initialDate,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  static const Color primaryGreen = Color(0xFF168A36);
  final AccountService accountService = AccountService();
  final AIService aiService = AIService();

  late String selectedType;

  String selectedCategory = "Ăn uống";
  String? selectedAccountId;
  bool isLoadingAccounts = true;
  bool isSuggestingCategory = false;
  List<AccountModel> accounts = [];
  String? suggestedCategory;
  String? suggestionMessage;

  DateTime selectedDate = DateTime.now();

  final TextEditingController amountController = TextEditingController();

  final TextEditingController noteController = TextEditingController();

  final List<Map<String, dynamic>> expenseCategories = [
    {"name": "Ăn uống", "icon": Icons.restaurant, "color": Colors.orange},

    {
      "name": "Đi lại",
      "icon": Icons.directions_bus,
      "color": Colors.deepOrange,
    },

    {"name": "Quần áo", "icon": Icons.checkroom, "color": Colors.blue},

    {"name": "Mỹ phẩm", "icon": Icons.brush, "color": Colors.pink},

    {"name": "Y tế", "icon": Icons.local_hospital, "color": Colors.green},

    {"name": "Giáo dục", "icon": Icons.school, "color": Colors.red},

    {"name": "Tiền điện", "icon": Icons.flash_on, "color": Colors.amber},

    {"name": "Tiền nhà", "icon": Icons.home, "color": Colors.brown},

    {"name": "Khác", "icon": Icons.more_horiz, "color": Colors.grey},
  ];

  final List<Map<String, dynamic>> incomeCategories = [
    {
      "name": "Tiền lương",
      "icon": Icons.account_balance_wallet,
      "color": Colors.green,
    },

    {"name": "Tiền phụ cấp", "icon": Icons.savings, "color": Colors.orange},

    {"name": "Tiền thưởng", "icon": Icons.card_giftcard, "color": Colors.red},

    {
      "name": "Thu nhập phụ",
      "icon": Icons.monetization_on,
      "color": Colors.blue,
    },

    {"name": "Đầu tư", "icon": Icons.trending_up, "color": Colors.teal},

    {"name": "Khác", "icon": Icons.more_horiz, "color": Colors.grey},
  ];

  @override
  void initState() {
    super.initState();

    if (widget.transaction != null) {
      selectedType = widget.transaction!["type"];
      selectedCategory = widget.transaction!["category"];
      amountController.text = widget.transaction!["amount"].toStringAsFixed(0);
      noteController.text = widget.transaction!["note"];
      selectedDate = widget.transaction!["date"];
      selectedAccountId = widget.transaction!["accountId"]?.toString();
    } else {
      selectedType = widget.type;
      selectedCategory = selectedType == "income" ? "Tiền lương" : "Ăn uống";
      if (widget.initialDate != null) {
        selectedDate = widget.initialDate!;
      }
    }
    loadAccounts();
  }

  List<Map<String, dynamic>> get currentCategories {
    return selectedType == "income" ? incomeCategories : expenseCategories;
  }

  Future<void> loadAccounts() async {
    try {
      await accountService.ensureDefaultAccount();
      final loadedAccounts = await accountService.getAccountsOnce();
      if (!mounted) return;

      final selectedExists =
          selectedAccountId != null &&
          loadedAccounts.any((account) => account.id == selectedAccountId);
      final defaultAccount = loadedAccounts.isEmpty
          ? null
          : loadedAccounts.firstWhere(
              (account) => account.isDefault,
              orElse: () => loadedAccounts.first,
            );

      setState(() {
        accounts = loadedAccounts;
        selectedAccountId = selectedExists
            ? selectedAccountId
            : defaultAccount?.id;
        isLoadingAccounts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoadingAccounts = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể tải tài khoản: $error")),
      );
    }
  }

  Future<void> pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  void changeType(String type) {
    setState(() {
      selectedType = type;

      selectedCategory = type == "income" ? "Tiền lương" : "Ăn uống";
      suggestedCategory = null;
      suggestionMessage = null;
    });
  }

  Future<void> suggestCategoryWithAI() async {
    final note = noteController.text.trim();
    final amount =
        double.tryParse(amountController.text.replaceAll(",", "").trim()) ?? 0;

    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nhập ghi chú trước khi gợi ý category")),
      );
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nhập số tiền trước khi gợi ý category")),
      );
      return;
    }

    setState(() {
      isSuggestingCategory = true;
      suggestionMessage = null;
    });

    try {
      final suggestion = await aiService.suggestCategory(
        note: note,
        amount: amount,
        type: selectedType,
      );
      if (!mounted) return;

      setState(() {
        suggestedCategory = suggestion;
        suggestionMessage = suggestion == null
            ? "AI chưa có gợi ý phù hợp."
            : "Gợi ý category: $suggestion";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        suggestedCategory = null;
        suggestionMessage = "Không thể gợi ý category lúc này.";
      });
    } finally {
      if (mounted) {
        setState(() {
          isSuggestingCategory = false;
        });
      }
    }
  }

  void applySuggestedCategory() {
    final suggestion = suggestedCategory;
    if (suggestion == null) return;
    final hasSuggestion = currentCategories.any(
      (category) => category["name"] == suggestion,
    );

    setState(() {
      selectedCategory = hasSuggestion ? suggestion : "Khác";
      suggestedCategory = null;
      suggestionMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isIncome = selectedType == "income";
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,

        iconTheme: const IconThemeData(color: Colors.white),

        title: Text(
          widget.transaction == null ? "Thêm giao dịch" : "Sửa giao dịch",

          style: const TextStyle(color: Colors.white),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 10),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),

              padding: const EdgeInsets.all(4),

              decoration: BoxDecoration(
                color: theme.cardColor,

                borderRadius: BorderRadius.circular(12),
              ),

              child: Row(
                children: [
                  Expanded(child: typeButton("expense", "Tiền chi")),

                  Expanded(child: typeButton("income", "Tiền thu")),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              color: theme.cardColor,

              padding: const EdgeInsets.all(16),

              child: Column(
                children: [
                  rowItem(
                    title: "Ngày",

                    child: InkWell(
                      onTap: pickDate,

                      child: Text(
                        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",

                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  Divider(color: theme.dividerColor),

                  rowItem(title: "Tài khoản", child: accountSelector()),

                  Divider(color: theme.dividerColor),

                  rowItem(
                    title: "Ghi chú",

                    child: TextField(
                      controller: noteController,
                      onChanged: (_) {
                        if (suggestedCategory == null &&
                            suggestionMessage == null) {
                          return;
                        }
                        setState(() {
                          suggestedCategory = null;
                          suggestionMessage = null;
                        });
                      },

                      style: TextStyle(color: theme.colorScheme.onSurface),

                      decoration: InputDecoration(
                        hintText: "Chưa nhập vào",

                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.45,
                          ),
                        ),

                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  Divider(color: theme.dividerColor),

                  rowItem(
                    title: isIncome ? "Tiền thu" : "Tiền chi",

                    child: TextField(
                      controller: amountController,

                      keyboardType: TextInputType.number,

                      style: TextStyle(
                        color: theme.colorScheme.onSurface,

                        fontSize: 28,

                        fontWeight: FontWeight.bold,
                      ),

                      decoration: InputDecoration(
                        hintText: "0",

                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.45,
                          ),
                        ),

                        border: InputBorder.none,

                        suffixText: "đ",

                        suffixStyle: TextStyle(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: isSuggestingCategory
                          ? null
                          : suggestCategoryWithAI,
                      icon: isSuggestingCategory
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text("Gợi ý bằng AI"),
                    ),
                  ),

                  categorySuggestionPanel(theme),

                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,

                    child: Text(
                      "Danh mục",

                      style: TextStyle(
                        color: theme.colorScheme.onSurface,

                        fontSize: 22,

                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  GridView.builder(
                    shrinkWrap: true,

                    physics: const NeverScrollableScrollPhysics(),

                    itemCount: currentCategories.length,

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,

                          mainAxisSpacing: 12,

                          crossAxisSpacing: 12,

                          childAspectRatio: 1.25,
                        ),

                    itemBuilder: (context, index) {
                      final category = currentCategories[index];

                      final isSelected = selectedCategory == category["name"];

                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedCategory = category["name"];
                          });
                        },

                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,

                            borderRadius: BorderRadius.circular(10),

                            border: Border.all(
                              color: isSelected
                                  ? primaryGreen
                                  : theme.dividerColor,

                              width: isSelected ? 2.5 : 1,
                            ),
                          ),

                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,

                            children: [
                              Icon(
                                category["icon"],

                                color: category["color"],

                                size: 32,
                              ),

                              const SizedBox(height: 8),

                              Text(
                                category["name"],

                                textAlign: TextAlign.center,

                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,

                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),

              child: SizedBox(
                width: double.infinity,
                height: 58,

                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),

                  onPressed: () {
                    final amount = double.tryParse(
                      amountController.text.replaceAll(",", "").trim(),
                    );

                    if (amount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Vui lòng nhập số tiền hợp lệ"),
                        ),
                      );
                      return;
                    }
                    if (amount < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Số dư không được âm")),
                      );
                      return;
                    }
                    if (selectedAccountId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Vui lòng chọn tài khoản tiền"),
                        ),
                      );
                      return;
                    }

                    final transaction = {
                      "category": selectedCategory,
                      "amount": amount,
                      "note": noteController.text,
                      "type": selectedType,
                      "date": selectedDate,
                      "accountId": selectedAccountId,
                    };

                    Navigator.pop(context, transaction);
                  },

                  child: Text(
                    isIncome ? "Nhập khoản thu" : "Nhập khoản chi",

                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget typeButton(String type, String title) {
    bool isSelected = selectedType == type;

    return GestureDetector(
      onTap: () => changeType(type),

      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),

        decoration: BoxDecoration(
          color: isSelected ? primaryGreen : Colors.transparent,

          borderRadius: BorderRadius.circular(10),
        ),

        child: Center(
          child: Text(
            title,

            style: TextStyle(
              color: isSelected ? Colors.white : primaryGreen,

              fontSize: 18,

              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget categorySuggestionPanel(ThemeData theme) {
    if (suggestionMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestionMessage!,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (suggestedCategory != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: applySuggestedCategory,
                  child: const Text("Chọn"),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      suggestedCategory = null;
                      suggestionMessage = null;
                    });
                  },
                  child: const Text("Bỏ qua"),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget rowItem({required String title, required Widget child}) {
    return Row(
      children: [
        SizedBox(
          width: 100,

          child: Text(
            title,

            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Expanded(child: child),
      ],
    );
  }

  Widget accountSelector() {
    if (isLoadingAccounts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }

    if (accounts.isEmpty) {
      return Text(
        "Chưa có tài khoản",
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.68),
          fontSize: 16,
        ),
      );
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedAccountId,
        isExpanded: true,
        items: accounts.map((account) {
          return DropdownMenuItem<String>(
            value: account.id,
            child: Text(
              account.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            selectedAccountId = value;
          });
        },
      ),
    );
  }
}
