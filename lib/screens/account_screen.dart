import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/account_model.dart';
import '../services/account_service.dart';
import '../widgets/app_ui.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AccountService accountService = AccountService();

  @override
  void initState() {
    super.initState();
    () async {
      try {
        await accountService.ensureDefaultAccount();
      } catch (_) {}
    }();
  }

  double netWorth(List<AccountModel> accounts) {
    return accounts.fold(0, (total, account) => total + account.balance);
  }

  Future<void> showAccountSheet({
    AccountModel? account,
    required bool isFirstAccount,
  }) async {
    final saved = await showModalBottomSheet<AccountModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Theme.of(context).bottomSheetTheme.backgroundColor ??
          Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return _AccountFormSheet(
          account: account,
          isDefaultOnCreate: isFirstAccount,
        );
      },
    );
    if (!mounted || saved == null) return;

    try {
      if (account == null) {
        await accountService.addAccount(saved);
      } else {
        await accountService.updateAccount(saved);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã lưu tài khoản")));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể lưu tài khoản: $error")),
      );
    }
  }

  Future<void> setDefault(AccountModel account) async {
    final id = account.id;
    if (id == null) return;
    try {
      await accountService.setDefaultAccount(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Đã đặt '${account.name}' làm mặc định")),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Không thể đặt mặc định: $error")));
    }
  }

  Future<void> deleteAccount(AccountModel account) async {
    final id = account.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Xóa tài khoản"),
          content: Text("Xóa tài khoản '${account.name}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text("Xóa"),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await accountService.deleteAccount(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã xóa tài khoản")));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không thể xóa tài khoản: $error")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppUi.pageBackground(context),
      appBar: AppBar(
        title: const Text(
          "Tài khoản",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<AccountModel>>(
        stream: accountService.getAccountsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final accounts = snapshot.data!;
          final defaultAccount =
              accounts.where((account) {
                return account.isDefault;
              }).isEmpty
              ? null
              : accounts.firstWhere((account) => account.isDefault);
          return Column(
            children: [
              _NetWorthBanner(
                netWorth: netWorth(accounts),
                accountCount: accounts.length,
                defaultAccount: defaultAccount,
                onAdd: () => showAccountSheet(isFirstAccount: accounts.isEmpty),
              ),
              Expanded(
                child: accounts.isEmpty
                    ? _EmptyAccountState(
                        onAdd: () => showAccountSheet(isFirstAccount: true),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: accounts.length,
                        itemBuilder: (context, index) {
                          final account = accounts[index];
                          return _AccountCard(
                            account: account,
                            onEdit: () => showAccountSheet(
                              account: account,
                              isFirstAccount: false,
                            ),
                            onSetDefault: () => setDefault(account),
                            onDelete: () => deleteAccount(account),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppUi.primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () => showAccountSheet(isFirstAccount: false),
        tooltip: "Thêm tài khoản",
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NetWorthBanner extends StatelessWidget {
  final double netWorth;
  final int accountCount;
  final AccountModel? defaultAccount;
  final VoidCallback onAdd;

  const _NetWorthBanner({
    required this.netWorth,
    required this.accountCount,
    required this.defaultAccount,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppUi.lightGreen, AppUi.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppUi.primaryGreen.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$accountCount tài khoản",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  AppUi.money(netWorth),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Mặc định: ${defaultAccount?.name ?? "Chưa có"}",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: onAdd,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
            tooltip: "Thêm tài khoản",
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AccountModel account;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _AccountCard({
    required this.account,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = AccountTypeUi.fromValue(account.type);

    return AppPanel(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: type.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(type.icon, color: type.color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppUi.primaryText(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (account.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppUi.primaryGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Mặc định",
                          style: TextStyle(
                            color: AppUi.primaryGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  type.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppUi.secondaryText(context)),
                ),
                const SizedBox(height: 6),
                Text(
                  "${AppUi.money(account.balance)} ${account.currency}",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppUi.primaryGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == "edit") onEdit();
              if (value == "default") onSetDefault();
              if (value == "delete") onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: "edit", child: Text("Sửa")),
              if (!account.isDefault)
                const PopupMenuItem(
                  value: "default",
                  child: Text("Đặt mặc định"),
                ),
              const PopupMenuItem(value: "delete", child: Text("Xóa")),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountFormSheet extends StatefulWidget {
  final AccountModel? account;
  final bool isDefaultOnCreate;

  const _AccountFormSheet({this.account, required this.isDefaultOnCreate});

  @override
  State<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<_AccountFormSheet> {
  late final TextEditingController nameController;
  late final TextEditingController balanceController;
  late String selectedType;
  late String currency;
  late bool isDefault;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    nameController = TextEditingController(text: account?.name ?? "");
    balanceController = TextEditingController(
      text: account == null ? "" : account.balance.toStringAsFixed(0),
    );
    selectedType = account?.type ?? "cash";
    currency = account?.currency ?? "VND";
    isDefault = account?.isDefault ?? widget.isDefaultOnCreate;
  }

  @override
  void dispose() {
    nameController.dispose();
    balanceController.dispose();
    super.dispose();
  }

  void save() {
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final balance =
        double.tryParse(balanceController.text.replaceAll(",", "").trim()) ?? 0;
    if (balance < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Số dư không được âm")));
      return;
    }
    final typeUi = AccountTypeUi.fromValue(selectedType);

    Navigator.pop(
      context,
      AccountModel(
        id: widget.account?.id,
        userId: widget.account?.userId,
        name: name,
        type: selectedType,
        balance: balance,
        currency: currency,
        isDefault: isDefault,
        icon: typeUi.iconName,
        color: typeUi.colorValue,
        createdAt: widget.account?.createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.account == null ? "Thêm tài khoản" : "Sửa tài khoản",
            style: TextStyle(
              color: AppUi.primaryText(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "Tên tài khoản",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: balanceController,
            readOnly: widget.account != null,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "Số dư",
              suffixText: "đ",
              helperText: widget.account == null
                  ? null
                  : "Số dư được cập nhật từ giao dịch",
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedType,
            decoration: const InputDecoration(
              labelText: "Loại tài khoản",
              border: OutlineInputBorder(),
            ),
            items: AccountTypeUi.values.map((type) {
              return DropdownMenuItem(
                value: type.value,
                child: Row(
                  children: [
                    Icon(type.icon, color: type.color, size: 20),
                    const SizedBox(width: 8),
                    Text(type.label),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedType = value ?? "cash";
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: currency,
            decoration: const InputDecoration(
              labelText: "Tiền tệ",
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: "VND", child: Text("VND")),
              DropdownMenuItem(value: "USD", child: Text("USD")),
              DropdownMenuItem(value: "EUR", child: Text("EUR")),
            ],
            onChanged: (value) {
              setState(() {
                currency = value ?? "VND";
              });
            },
          ),
          SwitchListTile(
            value: isDefault,
            onChanged: (value) {
              setState(() {
                isDefault = value;
              });
            },
            activeThumbColor: AppUi.primaryGreen,
            contentPadding: EdgeInsets.zero,
            title: Text(
              "Đặt làm tài khoản mặc định",
              style: TextStyle(color: AppUi.primaryText(context)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUi.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                "Lưu",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAccountState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyAccountState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: AppUi.primaryGreen,
            ),
            const SizedBox(height: 12),
            Text(
              "Chưa có tài khoản",
              style: TextStyle(
                color: AppUi.primaryText(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Thêm tài khoản tiền để theo dõi số dư thật trên Firestore.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppUi.secondaryText(context)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text("Thêm tài khoản"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppUi.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "Không thể tải tài khoản: $message",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}

enum AccountTypeUi {
  cash("cash", "Tiền mặt", Icons.payments, AppUi.primaryGreen),
  bank("bank", "Ngân hàng", Icons.account_balance, Colors.blue),
  eWallet("ewallet", "Ví điện tử", Icons.phone_android, Colors.deepPurple),
  card("card", "Thẻ", Icons.credit_card, Colors.indigo),
  other("other", "Khác", Icons.wallet, Colors.blueGrey);

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const AccountTypeUi(this.value, this.label, this.icon, this.color);

  String get iconName {
    switch (this) {
      case AccountTypeUi.cash:
        return "payments";
      case AccountTypeUi.bank:
        return "account_balance";
      case AccountTypeUi.eWallet:
        return "phone_android";
      case AccountTypeUi.card:
        return "credit_card";
      case AccountTypeUi.other:
        return "wallet";
    }
  }

  int get colorValue {
    switch (this) {
      case AccountTypeUi.cash:
        return 0xFF168A36;
      case AccountTypeUi.bank:
        return 0xFF2196F3;
      case AccountTypeUi.eWallet:
        return 0xFF673AB7;
      case AccountTypeUi.card:
        return 0xFF3F51B5;
      case AccountTypeUi.other:
        return 0xFF607D8B;
    }
  }

  static AccountTypeUi fromValue(String value) {
    final normalized = value.trim().toLowerCase();
    return AccountTypeUi.values.firstWhere(
      (type) => type.value == normalized,
      orElse: () => AccountTypeUi.other,
    );
  }
}
