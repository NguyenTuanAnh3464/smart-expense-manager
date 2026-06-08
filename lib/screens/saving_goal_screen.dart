import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/saving_goal_model.dart';
import '../services/saving_goal_service.dart';
import '../widgets/app_ui.dart';

class SavingGoalScreen extends StatefulWidget {
  const SavingGoalScreen({super.key});

  @override
  State<SavingGoalScreen> createState() => _SavingGoalScreenState();
}

class _SavingGoalScreenState extends State<SavingGoalScreen> {
  final SavingGoalService goalService = SavingGoalService();
  final DateFormat dateFormatter = DateFormat("dd/MM/yyyy");

  Future<void> openGoalSheet({SavingGoalModel? goal}) async {
    final saved = await showModalBottomSheet<SavingGoalModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Theme.of(context).bottomSheetTheme.backgroundColor ??
          Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _SavingGoalFormSheet(goal: goal),
    );
    if (!mounted || saved == null) return;

    try {
      if (goal == null) {
        await goalService.addGoal(saved);
      } else {
        await goalService.updateGoal(saved);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã lưu mục tiêu")));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Không thể lưu mục tiêu: $error")));
    }
  }

  Future<void> deleteGoal(SavingGoalModel goal) async {
    final id = goal.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Xóa mục tiêu"),
        content: Text("Xóa mục tiêu '${goal.title}'?"),
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
      ),
    );
    if (!mounted || confirmed != true) return;

    try {
      await goalService.deleteGoal(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã xóa mục tiêu")));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Không thể xóa mục tiêu: $error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Chưa đăng nhập")));
    }

    return Scaffold(
      backgroundColor: AppUi.pageBackground(context),
      appBar: AppBar(
        title: const Text(
          "Mục tiêu tiết kiệm",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppUi.primaryGreen,
        foregroundColor: Colors.white,
        onPressed: () => openGoalSheet(),
        tooltip: "Thêm mục tiêu",
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<SavingGoalModel>>(
        stream: goalService.getGoalsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString());
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final goals = snapshot.data!;
          if (goals.isEmpty) {
            return _EmptyGoalState(onAdd: () => openGoalSheet());
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return _SavingGoalCard(
                goal: goal,
                deadlineText: dateFormatter.format(goal.deadline),
                onEdit: () => openGoalSheet(goal: goal),
                onDelete: () => deleteGoal(goal),
              );
            },
          );
        },
      ),
    );
  }
}

class _SavingGoalCard extends StatelessWidget {
  final SavingGoalModel goal;
  final String deadlineText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SavingGoalCard({
    required this.goal,
    required this.deadlineText,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final percent = goal.progress * 100;
    final isDone = goal.currentAmount >= goal.targetAmount;

    return AppPanel(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppUi.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDone ? Icons.check_circle_outline : Icons.savings,
                  color: AppUi.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppUi.primaryText(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Hạn: $deadlineText",
                      style: TextStyle(color: AppUi.secondaryText(context)),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == "edit") onEdit();
                  if (value == "delete") onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: "edit", child: Text("Sửa")),
                  PopupMenuItem(value: "delete", child: Text("Xóa")),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: goal.progress,
              color: AppUi.primaryGreen,
              backgroundColor: Theme.of(context).dividerColor,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  "${AppUi.money(goal.currentAmount)} / ${AppUi.money(goal.targetAmount)}",
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppUi.secondaryText(context)),
                ),
              ),
              Text(
                "${percent.toStringAsFixed(0)}%",
                style: const TextStyle(
                  color: AppUi.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SavingGoalFormSheet extends StatefulWidget {
  final SavingGoalModel? goal;

  const _SavingGoalFormSheet({this.goal});

  @override
  State<_SavingGoalFormSheet> createState() => _SavingGoalFormSheetState();
}

class _SavingGoalFormSheetState extends State<_SavingGoalFormSheet> {
  late final TextEditingController titleController;
  late final TextEditingController targetController;
  late final TextEditingController currentController;
  late DateTime deadline;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    titleController = TextEditingController(text: goal?.title ?? "");
    targetController = TextEditingController(
      text: goal == null ? "" : goal.targetAmount.toStringAsFixed(0),
    );
    currentController = TextEditingController(
      text: goal == null ? "" : goal.currentAmount.toStringAsFixed(0),
    );
    deadline = goal?.deadline ?? DateTime.now().add(const Duration(days: 30));
  }

  @override
  void dispose() {
    titleController.dispose();
    targetController.dispose();
    currentController.dispose();
    super.dispose();
  }

  Future<void> pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: deadline,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() {
      deadline = picked;
    });
  }

  void save() {
    final title = titleController.text.trim();
    final target =
        double.tryParse(targetController.text.replaceAll(",", "").trim()) ?? 0;
    final current =
        double.tryParse(currentController.text.replaceAll(",", "").trim()) ?? 0;

    if (title.isEmpty || target <= 0 || current < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập mục tiêu hợp lệ")),
      );
      return;
    }

    Navigator.pop(
      context,
      SavingGoalModel(
        id: widget.goal?.id,
        userId: widget.goal?.userId,
        title: title,
        targetAmount: target,
        currentAmount: current,
        deadline: deadline,
        createdAt: widget.goal?.createdAt,
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
            widget.goal == null ? "Thêm mục tiêu" : "Sửa mục tiêu",
            style: TextStyle(
              color: AppUi.primaryText(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: "Tên mục tiêu",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: targetController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: "Số tiền mục tiêu",
              suffixText: "đ",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: currentController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: "Đã tiết kiệm",
              suffixText: "đ",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event, color: AppUi.primaryGreen),
            title: const Text("Hạn hoàn thành"),
            subtitle: Text(DateFormat("dd/MM/yyyy").format(deadline)),
            trailing: const Icon(Icons.chevron_right),
            onTap: pickDeadline,
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

class _EmptyGoalState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyGoalState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.savings, size: 58, color: AppUi.primaryGreen),
            const SizedBox(height: 12),
            Text(
              "Chưa có mục tiêu tiết kiệm",
              style: TextStyle(
                color: AppUi.primaryText(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text("Thêm mục tiêu"),
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
          "Không thể tải mục tiêu: $message",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }
}
