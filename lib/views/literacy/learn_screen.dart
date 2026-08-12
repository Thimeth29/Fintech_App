import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/app_viewmodel.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final p = vm.currentPersona;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Financial literacy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 2),
        Text(
          'Assessment progress & language',
          style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 12),
        ),
        const SizedBox(height: 10),
        // Language Pills
        Row(
          children: [
            _buildLangPill(vm, 'English', 'en'),
            const SizedBox(width: 6),
            _buildLangPill(vm, 'සිංහල', 'si'),
            const SizedBox(width: 6),
            _buildLangPill(vm, 'தமிழ்', 'ta'),
          ],
        ),
        const SizedBox(height: 18),
        // Quiz Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppTheme.gold,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${p.quiz.split('%')[0].split(' ').last}%',
                  style: GoogleFonts.newsreader(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.quiz,
                      style: GoogleFonts.ibmPlexSans(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Pre/post test, Cronbach's Alpha validated",
                      style: GoogleFonts.ibmPlexSans(fontSize: 10.5, color: AppTheme.sage),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Section label
        Text(
          'NEXT MODULE',
          style: GoogleFonts.ibmPlexMono(
            fontSize: 10.5,
            letterSpacing: 0.08,
            color: AppTheme.sage,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Module Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Understanding treasury bonds',
                style: GoogleFonts.ibmPlexSans(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 6),
              Text(
                'A short, plain-language lesson on how CBSL treasury bonds work and when they fit your goals.',
                style: GoogleFonts.ibmPlexSans(fontSize: 11.5, color: const Color(0xFF5A655E), height: 1.5),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.ink,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                ),
                child: const Text('Start lesson (4 min)', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLangPill(AppViewModel vm, String text, String code) {
    final active = vm.selectedLanguage == code;
    return GestureDetector(
      onTap: () => vm.setLanguage(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.ink : AppTheme.white,
          border: Border.all(color: active ? AppTheme.ink : AppTheme.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: active ? AppTheme.white : AppTheme.text,
          ),
        ),
      ),
    );
  }
}
