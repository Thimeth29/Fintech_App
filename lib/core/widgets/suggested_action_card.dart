import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../views/bot/chat_screen.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// The "here's what to do next" box every analytics/expenditure page ends with.
class SuggestedActionCard extends StatelessWidget {
  final String action;

  const SuggestedActionCard({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      backgroundColor: AppColors.mintBg,
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested action',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textDark,
                    height: 1.35,
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

/// Button placed at bottom of investment/expenditure pages that opens FinBot AI.
class AskBotButton extends StatelessWidget {
  final String? seedContext;

  const AskBotButton({super.key, this.seedContext});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.smart_toy_rounded, size: 20),
        label: Text(
          'ASK FINBOT AI',
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(seedContext: seedContext),
          ),
        ),
      ),
    );
  }
}

