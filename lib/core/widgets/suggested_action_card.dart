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
      borderColor: AppColors.accentCyan.withValues(alpha: 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              gradient: AppGradients.action,
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
                    color: AppColors.accentCyan,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.onGlass,
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
        // White "Contact me"-style pill: deep-navy text and icon.
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.onLight,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ).copyWith(
          shadowColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.35)),
          elevation: const WidgetStatePropertyAll(6),
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

