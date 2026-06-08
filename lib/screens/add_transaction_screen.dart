import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../services/ai_service.dart';
import '../services/account_service.dart';
import '../widgets/category_icon_helper.dart';

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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? categorySubscription;

  late String selectedType;

  String selectedCategory = "Ăn uống";
  String? selectedCategoryId;
  String? selectedAccountId;
  bool isLoadingAccounts = true;
  bool isSuggestingCategory = false;
  List<AccountModel> accounts = [];
  List<Map<String, dynamic>> customExpenseCategories = [];
  List<Map<String, dynamic>> customIncomeCategories = [];
  String? suggestedCategory;
  String? suggestionMessage;

  DateTime selectedDate = DateTime.now();

  final TextEditingController amountController = TextEditingController();

  final TextEditingController noteController = TextEditingController();

  final List<Map<String, dynamic>> defaultExpenseCategories = [
    {
      "name": "Ăn uống",
      "iconName": "restaurant",
      "icon": Icons.restaurant,
      "color": Colors.orange,
    },

    {
      "name": "Đi lại",
      "iconName": "directions_bus",
      "icon": Icons.directions_bus,
      "color": Colors.deepOrange,
    },

    {
      "name": "Quần áo",
      "iconName": "checkroom",
      "icon": Icons.checkroom,
      "color": Colors.blue,
    },

    {"name": "Mỹ phẩm", "iconName": "spa", "icon": Icons.brush, "color": Colors.pink},

    {
      "name": "Y tế",
      "iconName": "local_hospital",
      "icon": Icons.local_hospital,
      "color": Colors.green,
    },

    {"name": "Giáo dục", "iconName": "school", "icon": Icons.school, "color": Colors.red},

    {
      "name": "Tiền điện",
      "iconName": "electrical_services",
      "icon": Icons.flash_on,
      "color": Colors.amber,
    },

    {"name": "Tiền nhà", "iconName": "home", "icon": Icons.home, "color": Colors.brown},

    {"name": "Khác", "iconName": "more_horiz", "icon": Icons.more_horiz, "color": Colors.grey},
  ];

  final List<Map<String, dynamic>> defaultIncomeCategories = [
    {
      "name": "Tiền lương",
      "iconName": "account_balance_wallet",
      "icon": Icons.account_balance_wallet,
      "color": Colors.green,
    },

    {
      "name": "Tiền phụ cấp",
      "iconName": "savings",
      "icon": Icons.savings,
      "color": Colors.orange,
    },

    {
      "name": "Tiền thưởng",
      "iconName": "card_giftcard",
      "icon": Icons.card_giftcard,
      "color": Colors.red,
    },

    {
      "name": "Thu nhập phụ",
      "iconName": "attach_money",
      "icon": Icons.monetization_on,
      "color": Colors.blue,
    },

    {"name": "Đầu tư", "iconName": "paid", "icon": Icons.trending_up, "color": Colors.teal},

    {"name": "Khác", "iconName": "more_horiz", "icon": Icons.more_horiz, "color": Colors.grey},
  ];

  @override
  void initState() {
    super.initState();

    if (widget.transaction != null) {
      final transaction = TransactionModel.fromMap(widget.transaction!);
      selectedType = transaction.type;
      selectedCategory = transaction.category;
      selectedCategoryId = widget.transaction!["categoryId"]?.toString();
      amountController.text = transaction.amount.toStringAsFixed(0);
      noteController.text = transaction.note;
      selectedDate = transaction.date;
      selectedAccountId = widget.transaction!["accountId"]?.toString();
    } else {
      selectedType = widget.type;
      selectedCategory = selectedType == "income" ? "Tiền lương" : "Ăn uống";
      if (widget.initialDate != null) {
        selectedDate = widget.initialDate!;
      }
    }
    loadAccounts();
    listenCustomCategories();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    categorySubscription?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get currentCategories {
    return selectedType == "income"
        ? _mergeCategories(defaultIncomeCategories, customIncomeCategories)
        : _mergeCategories(defaultExpenseCategories, customExpenseCategories);
  }

  List<Map<String, dynamic>> get mainCategories {
    return currentCategories
        .where((category) => category["name"]?.toString() != "Khác")
        .take(5)
        .toList();
  }

  List<Map<String, dynamic>> get otherCategories {
    final mainNames = mainCategories
        .map((category) => category["name"]?.toString())
        .whereType<String>()
        .toSet();
    return currentCategories
        .where((category) => !mainNames.contains(category["name"]?.toString()))
        .toList();
  }

  Map<String, dynamic>? get selectedCategoryData {
    for (final category in currentCategories) {
      final id = category["id"]?.toString();
      final name = category["name"]?.toString();
      if (selectedCategoryId != null &&
          selectedCategoryId!.isNotEmpty &&
          id == selectedCategoryId) {
        return category;
      }
      if ((selectedCategoryId == null || selectedCategoryId!.isEmpty) &&
          name == selectedCategory) {
        return category;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _mergeCategories(
    List<Map<String, dynamic>> defaults,
    List<Map<String, dynamic>> custom,
  ) {
    final merged = <Map<String, dynamic>>[];
    final names = <String>{};
    for (final category in [...defaults, ...custom]) {
      final name = category["name"]?.toString().trim();
      if (name == null || name.isEmpty || !names.add(name)) continue;
      merged.add(category);
    }
    return merged;
  }

  void listenCustomCategories() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    categorySubscription = FirebaseFirestore.instance
        .collection("categories")
        .where("userId", isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      final expenses = <Map<String, dynamic>>[];
      final incomes = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data["name"]?.toString().trim();
        if (name == null || name.isEmpty) continue;
        final item = {
          "id": doc.id,
          "name": name,
          "iconName": data["iconName"]?.toString(),
          "icon": getCategoryIcon(data["iconName"]?.toString()),
          "color": _parseCategoryColor(data["color"]),
          "type": data["type"] == "income" ? "income" : "expense",
        };
        if (data["type"] == "income") {
          incomes.add(item);
        } else {
          expenses.add(item);
        }
      }
      if (!mounted) return;
      setState(() {
        customExpenseCategories = expenses;
        customIncomeCategories = incomes;
        if (!currentCategories.any(
          (category) =>
              (selectedCategoryId != null &&
                  selectedCategoryId!.isNotEmpty &&
                  category["id"]?.toString() == selectedCategoryId) ||
              category["name"] == selectedCategory,
        )) {
          selectedCategoryId = null;
          selectedCategory = selectedType == "income"
              ? currentCategories.first["name"].toString()
              : currentCategories.first["name"].toString();
        }
      });
    });
  }

  Color _parseCategoryColor(dynamic value) {
    if (value is int) return Color(value);
    if (value is num) return Color(value.toInt());
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return Color(parsed);
    }
    return primaryGreen;
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

      selectedCategory = currentCategories.first["name"].toString();
      selectedCategoryId = null;
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
      selectedCategoryId = null;
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
                        if (!noteController.value.composing.isCollapsed) {
                          return;
                        }
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],

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

                    itemCount: mainCategories.length + 1,

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,

                          mainAxisSpacing: 12,

                          crossAxisSpacing: 12,

                          childAspectRatio: 1.25,
                        ),

                    itemBuilder: (context, index) {
                      final isOtherTile = index == mainCategories.length;
                      final category = isOtherTile
                          ? {
                              "name": "Khác",
                              "icon": Icons.more_horiz,
                              "color": Colors.grey,
                            }
                          : mainCategories[index];

                      final isSelected = isOtherTile
                          ? otherCategories.any(
                              (item) => item["name"] == selectedCategory,
                            )
                          : selectedCategory == category["name"];

                      return InkWell(
                        onTap: () {
                          if (isOtherTile) {
                            showOtherCategoriesSheet();
                            return;
                          }
                          setState(() {
                            selectedCategory = category["name"].toString();
                            selectedCategoryId = null;
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
                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Số tiền giao dịch phải lớn hơn 0"),
                        ),
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

                    final categoryData = selectedCategoryData;
                    final categoryId = selectedCategoryId?.trim();
                    final categoryIconName =
                        categoryData?["iconName"]?.toString() ??
                        widget.transaction?["categoryIconName"]?.toString();
                    final normalizedCategoryIconName =
                        categoryIconName?.trim();
                    final categoryColor = categoryData?["color"];
                    final existingCategoryColor =
                        widget.transaction?["categoryColorValue"];
                    final categoryColorValue = categoryColor is Color
                        ? categoryColor.toARGB32()
                        : existingCategoryColor is int
                        ? existingCategoryColor
                        : existingCategoryColor is num
                        ? existingCategoryColor.toInt()
                        : null;
                    final transaction = {
                      "category": selectedCategory,
                      "categoryName": selectedCategory,
                      "categoryType": selectedType,
                      if (categoryId != null && categoryId.isNotEmpty)
                        "categoryId": categoryId,
                      if (normalizedCategoryIconName?.isNotEmpty == true)
                        "categoryIconName": normalizedCategoryIconName,
                      "categoryColorValue": categoryColorValue,
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

  Future<void> showOtherCategoriesSheet() async {
    final categories = otherCategories;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Không có danh mục khác")),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Chọn danh mục",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final name = category["name"]?.toString() ?? "Khác";
                      final icon = category["icon"] is IconData
                          ? category["icon"] as IconData
                          : Icons.category;
                      final color = category["color"] is Color
                          ? category["color"] as Color
                          : primaryGreen;
                      final isSelected = selectedCategory == name;
                      return ListTile(
                        leading: Icon(icon, color: color),
                        title: Text(name),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: primaryGreen)
                            : null,
                        onTap: () => Navigator.of(sheetContext).pop(category),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      selectedCategory = selected["name"]?.toString() ?? "Khác";
      selectedCategoryId = selected["id"]?.toString();
    });
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

