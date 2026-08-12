import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/app_viewmodel.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final p = vm.currentPersona;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Expense tracker',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 2),
        Text(
          'This month by category',
          style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 12),
        ),
        const SizedBox(height: 16),
        // Categories Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: p.cats.map((c) => _buildCategoryRow(c)).toList(),
          ),
        ),
        const SizedBox(height: 20),
        // Section label
        Text(
          'EMERGENCY FUND & PLANNING',
          style: GoogleFonts.ibmPlexMono(
            fontSize: 10.5,
            letterSpacing: 0.08,
            color: AppTheme.sage,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Planning Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Annual event budget (festivals, school terms)',
                style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: AppTheme.text),
              ),
              const SizedBox(height: 6),
              // Budget bar
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.paperAlt,
                  borderRadius: BorderRadius.circular(5),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 0.62,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.gold,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '62% funded for this year',
                style: GoogleFonts.ibmPlexMono(color: AppTheme.sage, fontSize: 10.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Log new expense CTA
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.ink,
            elevation: 0,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('+ Log new expense', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(dynamic c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(c.name, style: GoogleFonts.ibmPlexSans(fontSize: 12, color: AppTheme.text)),
              Text(
                'LKR ${c.amount}',
                style: GoogleFonts.ibmPlexMono(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.text),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.paperAlt,
              borderRadius: BorderRadius.circular(5),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: c.percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.gold,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
