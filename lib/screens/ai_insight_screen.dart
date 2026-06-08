import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/ai_context_service.dart';
import '../services/ai_service.dart';
import '../widgets/app_ui.dart';
import 'ai_chat_screen.dart';

class AIInsightScreen extends StatefulWidget {
  const AIInsightScreen({super.key});

  @override
  State<AIInsightScreen> createState() => _AIInsightScreenState();
}

class _AIInsightScreenState extends State<AIInsightScreen> {
  final AIService aiService = AIService();
  final AIContextService contextService = AIContextService();

  bool isLoading = false;
  String? insight;
  String? errorMessage;
  AIFinancialContext? lastContext;

  Future<void> generateInsight() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final data = await contextService.loadContext();
      final result = await aiService.generateFinancialInsight(
        transactions: data.transactions,
        accounts: data.accounts,
        budgets: data.budgets,
      );
      if (!mounted) return;
      setState(() {
        lastContext = data;
        insight = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Không thể tạo phân tích AI: $error";
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Chưa đăng nhập")));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "AI Insight",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          AppPanel(
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
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppUi.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Nhận xét từ AI",
                        style: TextStyle(
                          color: AppUi.primaryText(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Tạo phân tích ngắn từ giao dịch, tài khoản và ngân sách gần đây của bạn.",
                  style: TextStyle(color: AppUi.secondaryText(context)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : generateInsight,
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_outlined),
                    label: Text(
                      isLoading ? "Đang phân tích..." : "Tạo phân tích",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppUi.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (lastContext != null) _ContextSummary(contextData: lastContext!),
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            _ErrorPanel(message: errorMessage!),
          ],
          if (insight != null) ...[
            const SizedBox(height: 14),
            AppPanel(
              child: Text(
                insight!,
                style: TextStyle(
                  color: AppUi.primaryText(context),
                  height: 1.42,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            AppPanel(
              child: Text(
                "Chưa có phân tích. Nhấn nút tạo phân tích để AI đọc dữ liệu gần đây.",
                style: TextStyle(color: AppUi.secondaryText(context)),
              ),
            ),
          ],
          const SizedBox(height: 14),
          AppNavTile(
            icon: Icons.smart_toy_outlined,
            iconColor: AppUi.primaryGreen,
            title: "Mở Trợ lý AI",
            subtitle: "Hỏi đáp trực tiếp về chi tiêu",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIChatScreen()),
              );
            },
          ),
          Text(
            "Gợi ý từ AI chỉ mang tính tham khảo.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppUi.secondaryText(context), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ContextSummary extends StatelessWidget {
  final AIFinancialContext contextData;

  const _ContextSummary({required this.contextData});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SummaryMetricCard(
            title: "Giao dịch",
            amount: contextData.transactions.length.toString(),
            icon: Icons.receipt_long,
            color: AppUi.primaryGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SummaryMetricCard(
            title: "Ngân sách",
            amount: contextData.budgets.length.toString(),
            icon: Icons.savings_outlined,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;

  const _ErrorPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }
}
