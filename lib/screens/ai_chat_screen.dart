import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/ai_context_service.dart';
import '../services/ai_service.dart';
import '../widgets/app_ui.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final AIService aiService = AIService();
  final AIContextService contextService = AIContextService();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final List<_ChatMessage> messages = [];
  bool isLoading = false;
  String? errorMessage;

  final List<String> suggestions = const [
    "Tóm tắt chi tiêu tháng này",
    "Tôi tiêu nhiều nhất vào đâu?",
    "Gợi ý cách tiết kiệm tiền",
    "Phân tích ngân sách của tôi",
  ];

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> sendMessage([String? preset]) async {
    final message = (preset ?? messageController.text).trim();
    if (message.isEmpty || isLoading) return;

    setState(() {
      messages.add(_ChatMessage(text: message, isUser: true));
      messageController.clear();
      isLoading = true;
      errorMessage = null;
    });
    scrollToBottom();

    try {
      final data = await contextService.loadContext();
      final answer = await aiService.sendChatMessage(
        message: message,
        transactions: data.transactions,
        accounts: data.accounts,
        budgets: data.budgets,
      );
      if (!mounted) return;
      setState(() {
        messages.add(_ChatMessage(text: answer, isUser: false));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = "Không thể tải dữ liệu cho AI: $error";
        messages.add(
          const _ChatMessage(
            text: "AI tạm thời chưa sẵn sàng. Bạn có thể thử lại sau.",
            isUser: false,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        scrollToBottom();
      }
    }
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
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
          "Trợ lý AI",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _EmptyChatState(
                    suggestions: suggestions,
                    onTapSuggestion: sendMessage,
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return const _TypingBubble();
                      }
                      return _MessageBubble(message: messages[index]);
                    },
                  ),
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              "Gợi ý từ AI chỉ mang tính tham khảo.",
              style: TextStyle(
                color: AppUi.secondaryText(context),
                fontSize: 12,
              ),
            ),
          ),
          _ChatComposer(
            controller: messageController,
            isLoading: isLoading,
            onSend: sendMessage,
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onTapSuggestion;

  const _EmptyChatState({
    required this.suggestions,
    required this.onTapSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
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
                      Icons.smart_toy_outlined,
                      color: AppUi.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Bạn muốn phân tích điều gì?",
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
                "Trợ lý dùng giao dịch, tài khoản và ngân sách của bạn để trả lời. Nếu backend AI chưa cấu hình, app sẽ dùng phản hồi placeholder an toàn.",
                style: TextStyle(color: AppUi.secondaryText(context)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in suggestions)
                    ActionChip(
                      label: Text(suggestion),
                      avatar: const Icon(Icons.auto_awesome, size: 18),
                      onPressed: () => onTapSuggestion(suggestion),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final background = isUser ? AppUi.primaryGreen : theme.cardColor;
    final foreground = isUser ? Colors.white : theme.colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: isUser ? null : Border.all(color: theme.dividerColor),
          ),
          child: Text(
            message.text,
            style: TextStyle(color: foreground, height: 1.35),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;

  const _ChatComposer({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: "Hỏi AI về chi tiêu của bạn",
                  prefixIcon: Icon(Icons.psychology_outlined),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: isLoading ? null : onSend,
              icon: const Icon(Icons.send),
              tooltip: "Gửi",
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
