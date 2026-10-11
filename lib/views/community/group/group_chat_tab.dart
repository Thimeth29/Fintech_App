import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/community/community_math.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/group_models.dart';
import '../../../viewmodels/group_viewmodel.dart';
import '../widgets/community_widgets.dart';

class GroupChatTab extends StatefulWidget {
  const GroupChatTab({super.key});

  @override
  State<GroupChatTab> createState() => _GroupChatTabState();
}

class _GroupChatTabState extends State<GroupChatTab> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  ChatMessage? _replyTo;
  bool _sending = false;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // Reversed list: the end of the scroll is the oldest message.
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 80) {
        context.read<GroupViewModel>().loadOlderMessages();
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (hasPaymentDetails(text)) {
      showResult(context, 'That looks like a bank account or card number. Share payment details privately with the treasurer.');
      return;
    }
    setState(() => _sending = true);
    final vm = context.read<GroupViewModel>();
    final error = await vm.send(text, replyTo: _replyTo?.id);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      showResult(context, error);
    } else {
      _input.clear();
      setState(() => _replyTo = null);
    }
  }

  Future<void> _actions(ChatMessage m) async {
    final vm = context.read<GroupViewModel>();
    final mine = m.senderId == vm.myId;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.deepNavy,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.reply_rounded), title: const Text('Reply'), onTap: () => Navigator.pop(ctx, 'reply')),
          if (vm.isOfficer)
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(m.isPinned ? 'Unpin' : 'Pin for everyone'),
              onTap: () => Navigator.pop(ctx, 'pin'),
            ),
          if (mine || vm.isOfficer)
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: const Text('Remove message'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          if (!mine)
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.loss),
              title: const Text('Report message'),
              onTap: () => Navigator.pop(ctx, 'report'),
            ),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'reply':
        setState(() => _replyTo = m);
      case 'pin':
        await act(context, vm.pin(m.id, !m.isPinned));
      case 'remove':
        if (await confirmAction(context, 'Remove this message?', 'It will show as removed for everyone.', confirm: 'Remove')) {
          if (mounted) await act(context, vm.removeMessage(m.id));
        }
      case 'report':
        final error = await vm.reportMessage(m.id, 'inappropriate', null);
        if (mounted) showResult(context, error, 'Thanks. The message was reported for review.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GroupViewModel>();
    final msgs = vm.messages;
    if (msgs.length != _lastCount) {
      final grew = msgs.length > _lastCount && _lastCount != 0;
      _lastCount = msgs.length;
      if (grew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients && _scroll.position.pixels < 200) {
            _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
          }
          vm.service.markRead(vm.groupId).catchError((_) {});
        });
      }
    }
    final pinned = msgs.where((m) => m.isPinned && !m.isDeleted).toList();
    final reversed = msgs.reversed.toList();

    return Column(
      children: [
        if (pinned.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.innerFillSelected,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.5)),
            ),
            child: Row(children: [
              const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.accentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(pinned.last.body ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: cText(12.5)),
              ),
            ]),
          ),
        Expanded(
          child: msgs.isEmpty
              ? Center(child: Text('No messages yet. Say hello!', style: cText(13, color: AppColors.onGlassMuted)))
              : ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: reversed.length + (vm.hasOlderMessages ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == reversed.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2)),
                      );
                    }
                    final m = reversed[i];
                    final reply = m.replyTo == null ? null : msgs.where((x) => x.id == m.replyTo).firstOrNull;
                    return _Bubble(
                      message: m,
                      mine: m.senderId == vm.myId,
                      sender: vm.nameOf(m.senderId),
                      reply: reply,
                      replySender: reply == null ? null : vm.nameOf(reply.senderId),
                      onLongPress: m.isSystem || m.isDeleted ? null : () => _actions(m),
                    );
                  },
                ),
        ),
        if (!(vm.info?.isClosed ?? false))
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Column(
                children: [
                  if (_replyTo != null)
                    Row(children: [
                      const Icon(Icons.reply_rounded, size: 16, color: AppColors.onGlassMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Replying to ${vm.nameOf(_replyTo!.senderId)}: ${_replyTo!.body ?? ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: cText(12, color: AppColors.onGlassMuted)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _replyTo = null),
                      ),
                    ]),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 2000,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(hintText: 'Message the group', counterText: ''),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final String sender;
  final ChatMessage? reply;
  final String? replySender;
  final VoidCallback? onLongPress;

  const _Bubble({
    required this.message,
    required this.mine,
    required this.sender,
    this.reply,
    this.replySender,
    this.onLongPress,
  });

  String _time(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.innerFill, borderRadius: BorderRadius.circular(12)),
            child: Text(m.body ?? '', textAlign: TextAlign.center, style: cText(12, color: AppColors.onGlassMuted)),
          ),
        ),
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary.withValues(alpha: 0.85) : AppColors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: m.isPinned ? AppColors.accentCyan : AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine) Text(sender, style: cText(11.5, weight: FontWeight.w700, color: AppColors.accentCyan)),
              if (reply != null)
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                  child: Text('$replySender: ${reply!.body ?? 'removed'}',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: cText(11.5, color: AppColors.onGlassMuted)),
                ),
              Text(
                m.isDeleted ? 'Message removed' : (m.body ?? ''),
                style: cText(14, color: m.isDeleted ? AppColors.onGlassFaint : AppColors.onGlass),
              ),
              const SizedBox(height: 2),
              Text(_time(m.createdAt), style: cText(10, color: AppColors.onGlassFaint)),
            ],
          ),
        ),
      ),
    );
  }
}
