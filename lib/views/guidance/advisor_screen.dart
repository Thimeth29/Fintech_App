import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/app_viewmodel.dart';

class AdvisorScreen extends StatelessWidget {
  const AdvisorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final p = vm.currentPersona;
    final f = p.advice.factors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'AI Advisor',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 2),
        Text(
          'Recommendation with SHAP / LIME reasoning',
          style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 12),
        ),
        const SizedBox(height: 16),
        // Ledger
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            border: Border.all(color: AppTheme.ink),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Ledger Head
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: const BoxDecoration(
                  color: AppTheme.ink,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(13),
                    topRight: Radius.circular(13),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TODAY'S RECOMMENDATION",
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 10,
                            letterSpacing: .08,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.goldLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'For ${p.name.split(' ')[0]}',
                          style: GoogleFonts.newsreader(
                            color: AppTheme.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    // Seal
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.gold, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '87%',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.goldLight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Ledger Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.advice.message,
                      style: GoogleFonts.newsreader(fontSize: 15, height: 1.4, color: AppTheme.text),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'WHY THIS SUGGESTION',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10.5,
                        letterSpacing: .08,
                        color: AppTheme.sage,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 11),
                    ...f.map((factor) => _buildFactorItem(factor)),
                  ],
                ),
              ),
              // Ledger Foot
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppTheme.line, width: 1, style: BorderStyle.solid), // dashed in html
                  ),
                ),
                child: Text(
                  'SHAP + LIME · generated from your last 90 days of activity',
                  style: GoogleFonts.ibmPlexMono(color: AppTheme.sage, fontSize: 10),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Ask follow up CTA
        OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.ink),
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('Ask a follow-up', style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildFactorItem(dynamic factor) {
    final isPos = factor.direction == 'pos';
    final factorVal = factor.value;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(factor.name, style: GoogleFonts.ibmPlexSans(fontSize: 11.5, color: AppTheme.text)),
              Text(
                '${factorVal > 0 ? '+' : ''}$factorVal%',
                style: GoogleFonts.ibmPlexMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  color: isPos ? const Color(0xFF3F7A52) : AppTheme.clay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Progress bar
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.paperAlt,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: factorVal.abs() * 2 / 100, // math.abs(val)*2% in html
              child: Container(
                decoration: BoxDecoration(
                  color: isPos ? const Color(0xFF3F7A52) : AppTheme.clay,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
