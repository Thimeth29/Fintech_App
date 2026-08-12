import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/app_viewmodel.dart';

class OnboardScreen extends StatelessWidget {
  const OnboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final p = vm.currentPersona;
    final primaryColor = Color(int.parse(p.color.replaceAll('#', '0xFF')));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 26),
        // Persona Hero
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: primaryColor,
                child: Text(
                  p.init,
                  style: GoogleFonts.newsreader(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Welcome, ${p.name.split(' ')[0]}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 23),
              ),
              const SizedBox(height: 2),
              Text(
                '${p.role} · Tailored experience',
                style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        // Onboard cards
        _buildOnboardCard(
          icon: Icons.lightbulb_outline,
          title: 'Explainable AI advisor',
          description: 'Every suggestion comes with plain-language reasoning, not a black box.',
        ),
        _buildOnboardCard(
          icon: Icons.bar_chart_outlined,
          title: 'Risk-free sandbox',
          description: 'Practice fixed deposits, gold, forex, stocks and treasury bonds with mock funds.',
        ),
        _buildOnboardCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Expense prediction',
          description: 'An LSTM model forecasts next month\'s spend across critical, average and low levels.',
        ),
        _buildOnboardCard(
          icon: Icons.book_outlined,
          title: 'Multilingual literacy',
          description: 'Sinhala, Tamil and English financial education, matched to your progress.',
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => vm.setScreen('dashboard'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            elevation: 0,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('Continue to dashboard', style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildOnboardCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.gold, size: 18),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.text),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.ibmPlexSans(fontSize: 11, color: const Color(0xFF5A655E), height: 1.4),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
