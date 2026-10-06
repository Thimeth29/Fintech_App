// lib/views/bot/chat_screen.dart
//
// Pure UI for now — sending a message appends a canned local reply. Real
// AI/Supabase wiring (ChatViewModel) comes back in during the backend
// phase.
import 'package:flutter/material.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/chat_message_model.dart';

const _cannedReply = "I'm just a placeholder for now — once FinBot is wired up "
    "to live data, I'll give you a real answer here.";

class ChatScreen extends StatefulWidget {
  final String title;
  final String? seedContext;

  const ChatScreen({super.key, this.title = 'Ask the Bot', this.seedContext});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final List<ChatMessageModel> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [
      ChatMessageModel(
        role: ChatRole.bot,
        content: widget.seedContext == null || widget.seedContext!.isEmpty
            ? "Hi! I'm FinBot. Ask me anything about your finances."
            : "Hi! I see you're looking at: ${widget.seedContext}. What would you like to know?",
      ),
    ];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(ChatMessageModel(role: ChatRole.user, content: text.trim()));
      _messages.add(ChatMessageModel(role: ChatRole.bot, content: _cannedReply));
    });
    _controller.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    _scrollToBottom();
    return GradientScaffold(
      maxContentWidth: 720,
      appBar: TopNavBar(current: AppSection.bot, title: widget.title, showBackButton: true),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _Bubble(message: _messages[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Ask FinBot something...'),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: () => _send(_controller.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessageModel message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final primary = Theme.of(context).colorScheme.primary;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? primary : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          message.content,
          style: TextStyle(fontSize: 13.5, color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}
