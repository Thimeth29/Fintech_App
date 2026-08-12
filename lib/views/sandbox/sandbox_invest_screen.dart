import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/app_viewmodel.dart';

class SandboxInvestScreen extends StatelessWidget {
  const SandboxInvestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final p = vm.currentPersona;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sandbox portfolio',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 2),
        Text(
          'Practice investing — no real money at risk',
          style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 12),
        ),
        const SizedBox(height: 16),
        // Asset cards
        ...p.invest.map((inv) => _buildAssetCard(inv)),
        const SizedBox(height: 20),
        // Section label
        Text(
          'AVAILABLE INSTRUMENTS',
          style: GoogleFonts.ibmPlexMono(
            fontSize: 10.5,
            letterSpacing: 0.08,
            color: AppTheme.sage,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Tag pills
        const Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            TagWidget(text: 'Fixed Deposit'),
            TagWidget(text: 'Gold'),
            TagWidget(text: 'Forex'),
            TagWidget(text: 'CSE Stocks'),
            TagWidget(text: 'Treasury Bonds'),
            TagWidget(text: 'Community'),
          ],
        ),
        const SizedBox(height: 16),
        // Trade CTA
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            elevation: 0,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('Practice a trade', style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildAssetCard(dynamic inv) {
    final isUp = inv.direction == 'up';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inv.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text)),
              Text(inv.sub, style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 10.5)),
            ],
          ),
          Text(
            inv.change,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isUp ? const Color(0xFF3F7A52) : AppTheme.clay,
            ),
          )
        ],
      ),
    );
  }
}

class TagWidget extends StatelessWidget {
  final String text;
  const TagWidget({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.paperAlt,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: GoogleFonts.ibmPlexMono(fontSize: 9.5, color: AppTheme.ink),
      ),
    );
  }
}
