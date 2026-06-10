import 'dart:async';
import 'bank_image_upload_screen.dart';
import 'package:flutter/material.dart';
import 'add_transaction_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:intl/intl.dart';

import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../models/user_profile_model.dart';
import '../services/account_service.dart';
import '../services/profile_service.dart';
import '../services/transaction_service.dart';
import '../widgets/category_icon_helper.dart';
import '../widgets/transaction_style.dart';
import 'transaction_search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProfileService profileService = ProfileService();
  final AccountService accountService = AccountService();

  Widget summaryCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.18 : 0.06,
              ),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amount,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget actionButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.cardColor,
          foregroundColor: theme.colorScheme.primary,
          elevation: 1,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  final TransactionService transactionService = TransactionService();
  StreamSubscription<List<TransactionModel>>? transactionSubscription;

  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    listenTransactions();
    ensureDefaultAccount();
  }

  @override
  void dispose() {
    transactionSubscription?.cancel();
    super.dispose();
  }

  Future<void> ensureDefaultAccount() async {
    try {
      await accountService.ensureDefaultAccount();
    } catch (_) {}
  }

  void listenTransactions() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    transactionSubscription = transactionService.getTransactionsStream().listen(
      (data) {
        if (!mounted) return;
        setState(() {
          transactions = data.map(transactionToMap).toList();
        });
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không thể tải giao dịch: $error")),
        );
      },
    );
  }
  Map<String, dynamic> transactionToMap(TransactionModel transaction) {
    return {
      "id": transaction.id,
      "userId": transaction.userId,
      "category": transaction.category,
      "amount": transaction.amount,
      "note": transaction.note,
      "type": transaction.type,
      "date": transaction.date,
      if (transaction.accountId != null) "accountId": transaction.accountId,
      if (transaction.categoryId != null) "categoryId": transaction.categoryId,
      if (transaction.categoryName != null)
        "categoryName": transaction.categoryName,
      if (transaction.categoryType != null)
        "categoryType": transaction.categoryType,
      if (transaction.categoryIconName != null)
        "categoryIconName": transaction.categoryIconName,
      if (transaction.categoryColorValue != null)
        "categoryColorValue": transaction.categoryColorValue,
      if (transaction.goalId != null) "goalId": transaction.goalId,
      if (transaction.budgetId != null) "budgetId": transaction.budgetId,
      if (transaction.sourceBudgetCategory != null)
        "sourceBudgetCategory": transaction.sourceBudgetCategory,
      if (transaction.sourceBudgetMonth != null)
        "sourceBudgetMonth": transaction.sourceBudgetMonth,
      if (transaction.sourceBudgetYear != null)
        "sourceBudgetYear": transaction.sourceBudgetYear,
      if (transaction.source != null) "source": transaction.source,
      if (transaction.rawBankContent != null)
        "rawBankContent": transaction.rawBankContent,
      if (transaction.rawBankText != null) "rawBankText": transaction.rawBankText,
      if (transaction.bankTransactionTime != null)
        "bankTransactionTime": transaction.bankTransactionTime,
      if (transaction.bankAccountNumber != null)
        "bankAccountNumber": transaction.bankAccountNumber,
      if (transaction.bankFee != null) "bankFee": transaction.bankFee,
      if (transaction.balanceAfterFromBank != null)
        "balanceAfterFromBank": transaction.balanceAfterFromBank,
      if (transaction.bankImageUrl != null)
        "bankImageUrl": transaction.bankImageUrl,
    };
  }

  double get totalIncome {
    double total = 0;
    for (var item in transactions) {
      if (item["type"] == "income") {
        total += (item["amount"] as num).toDouble();
      }
    }
    return total;
  }

  double get totalExpense {
    double total = 0;
    for (var item in transactions) {
      if (item["type"] == "expense") {
        total += (item["amount"] as num).toDouble();
      }
    }
    return total;
  }

  Future<void> editTransaction(int index) async {
    final oldTransaction = transactions[index];

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(
          type: oldTransaction["type"],
          transaction: oldTransaction,
        ),
      ),
    );
    if (!mounted) return;

    if (result != null) {
      final id = oldTransaction["id"];

      try {
        if (id != null) {
          await transactionService.updateTransaction(id, result);
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không thể sửa giao dịch: $error")),
        );
      }
    }
  }
  void openBankImageScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BankImageUploadScreen(),
      ),
    );
  }

  Future<void> openAddTransaction(String type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddTransactionScreen(type: type)),
    );
    if (!mounted) return;

    if (result != null) {
      try {
        await addTransactionToFirestore(result);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không thể thêm giao dịch: $error")),
        );
      }
    }
  }

  String formatMoney(double amount) {
    final formatter = NumberFormat("#,###", "en_US");

    return "${formatter.format(amount)} VNĐ";
  }

  String getVietnameseWeekday(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return "Thứ 2";
      case DateTime.tuesday:
        return "Thứ 3";
      case DateTime.wednesday:
        return "Thứ 4";
      case DateTime.thursday:
        return "Thứ 5";
      case DateTime.friday:
        return "Thứ 6";
      case DateTime.saturday:
        return "Thứ 7";
      case DateTime.sunday:
        return "CN";
      default:
        return "";
    }
  }

  String formatDateWithWeekday(DateTime date) {
    final day = date.day.toString().padLeft(2, "0");
    final month = date.month.toString().padLeft(2, "0");
    final year = date.year.toString();
    return "$day/$month/$year (${getVietnameseWeekday(date)})";
  }

  Future<String?> addTransactionToFirestore(
    Map<String, dynamic> transaction,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    final docRef = await transactionService.addTransaction(transaction);
    return docRef.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          tooltip: "Đọc ảnh giao dịch",
          icon: const Icon(
            Icons.document_scanner_outlined,
            color: Colors.white,
          ),
          onPressed: openBankImageScanner,
        ),
        title: const Text("Smart Expense Manager"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        actions: [
          IconButton(
            tooltip: "Tìm kiếm",
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionSearchScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2EAD4B), Color(0xFF168A36)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),

                child: Row(
                  children: [
                    userAvatar(),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Người dùng",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),

                          const SizedBox(height: 2),

                          userIdentity(),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Số dư hiện tại",
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),

                        const SizedBox(height: 2),

                        defaultAccountBalance(),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  summaryCard(
                    title: "Tổng thu",
                    amount: formatMoney(totalIncome),
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),

                  const SizedBox(width: 12),

                  summaryCard(
                    title: "Tổng chi",
                    amount: formatMoney(totalExpense),
                    icon: Icons.trending_down,
                    color: Colors.red,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  actionButton(
                    title: "Thêm thu",
                    icon: Icons.add,
                    onPressed: () {
                      openAddTransaction("income");
                    },
                  ),

                  const SizedBox(width: 12),

                  actionButton(
                    title: "Thêm chi",
                    icon: Icons.remove,
                    onPressed: () {
                      openAddTransaction("expense");
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),

              const Text(
                "Giao dịch gần đây",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              transactions.isEmpty
                  ? const Text("Chưa có giao dịch nào")
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final item = transactions[index];
                        final type = item["type"];
                        final transactionColor = getTransactionColorFromData(
                          type: type,
                          categoryColorValue: item["categoryColorValue"],
                        );
                        final transactionDate = item["date"] is DateTime
                            ? item["date"] as DateTime
                            : DateTime.fromMillisecondsSinceEpoch(0);
                        final noteText = item["note"].toString().trim().isEmpty
                            ? "Không có ghi chú"
                            : item["note"].toString();

                        return Slidable(
                          key: ValueKey(item["id"] ?? index),
                          endActionPane: ActionPane(
                            motion: const StretchMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (_) async {
                                  final id = item["id"];

                                  try {
                                    if (id != null) {
                                      await transactionService
                                          .deleteTransaction(id);
                                    }
                                  } catch (error) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Không thể xóa giao dịch: $error",
                                        ),
                                      ),
                                    );
                                  }
                                },
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: "Xóa",
                              ),
                            ],
                          ),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              onTap: () {
                                editTransaction(index);
                              },
                              leading: Icon(
                                getTransactionIconFromData(
                                  type: type,
                                  categoryIconName: item["categoryIconName"]
                                      ?.toString(),
                                ),
                                color: transactionColor,
                                size: 30,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item["category"],
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    "${TransactionStyle.signFor(type)}${formatMoney((item["amount"] as num).toDouble())}",
                                    style: TextStyle(
                                      color: transactionColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.45),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    noteText,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.68),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatDateWithWeekday(transactionDate),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.55),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget userIdentity() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<UserProfileModel?>(
      stream: profileService.getProfileStream(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final profileName = profile?.name.trim();
        final authName = user?.displayName?.trim();
        final email = profile?.email.trim().isNotEmpty == true
            ? profile!.email.trim()
            : user?.email?.trim() ?? "";

        final displayName =
            profileName != null &&
                profileName.isNotEmpty &&
                profileName != "Người dùng"
            ? profileName
            : authName != null && authName.isNotEmpty
            ? authName
            : email.isNotEmpty
            ? email
            : "Người dùng";

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (email.isNotEmpty && email != displayName) ...[
              const SizedBox(height: 2),
              Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget userAvatar() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<UserProfileModel?>(
      stream: profileService.getProfileStream(),
      builder: (context, snapshot) {
        final profilePhoto = snapshot.data?.photoURL?.trim();
        final authPhoto = user?.photoURL?.trim();
        final photoUrl = profilePhoto?.isNotEmpty == true
            ? profilePhoto
            : authPhoto?.isNotEmpty == true
            ? authPhoto
            : null;

        return _ProfileAvatar(photoUrl: photoUrl);
      },
    );
  }

  Widget defaultAccountBalance() {
    return StreamBuilder<List<AccountModel>>(
      stream: accountService.getAccountsStream(),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <AccountModel>[];
        final defaultAccount = accounts.isEmpty
            ? null
            : accounts.firstWhere(
                (account) => account.isDefault,
                orElse: () => accounts.first,
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMoney(defaultAccount?.balance ?? 0),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (defaultAccount != null) ...[
              const SizedBox(height: 2),
              Text(
                defaultAccount.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? photoUrl;

  const _ProfileAvatar({required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url.isEmpty
          ? const Icon(Icons.person, color: Colors.white, size: 24)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.person, color: Colors.white, size: 24);
              },
            ),
    );
  }
}

