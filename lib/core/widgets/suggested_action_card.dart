import 'package:flutter/material.dart';
import '../../views/bot/chat_screen.dart';

/// The "here's what to do next" box every analytics/expenditure page ends
/// with, per the app spec.
class SuggestedActionCard extends StatelessWidget {
  final String action;

  const SuggestedActionCard({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, color: Colors.black87),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suggested action',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(action, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Button placed at the bottom of every investment/expenditure page that
/// opens the shared FinBot chat, optionally seeded with context so the
/// bot already knows what page the user was on.
class AskBotButton extends StatelessWidget {
  final String? seedContext;

  const AskBotButton({super.key, this.seedContext});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('ASK THE BOT'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(seedContext: seedContext),
          ),
        ),
      ),
    );
  }
}
