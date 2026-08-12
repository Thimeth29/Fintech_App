import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/chat_message_model.dart';
import '../../services/auth_service.dart';
import '../../viewmodels/chat_viewmodel.dart';

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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatViewModel()
        ..seed(widget.seedContext ?? '')
        ..loadFinancialContext(userId: AuthService().currentUser?.id),
      child: GradientScaffold(
        appBar: TopNavBar(current: AppSection.bot, title: widget.title, showBackButton: true),
        body: Consumer<ChatViewModel>(
          builder: (context, vm, _) {
            _scrollToBottom();
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: vm.messages.length,
                    itemBuilder: (context, i) => _Bubble(message: vm.messages[i]),
                  ),
                ),
                if (vm.isSending)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('FinBot is typing…', style: TextStyle(fontSize: 12)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(hintText: 'Ask FinBot something...'),
                          onSubmitted: (text) {
                            vm.send(text);
                            _controller.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          vm.send(_controller.text);
                          _controller.clear();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.content, style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }
}
