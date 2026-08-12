import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/app_viewmodel.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final p = vm.currentPersona;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 34),
        Center(
          child: Column(
            children: [
              Text(
                'Sahurada',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 11,
                  letterSpacing: .14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.sage,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                'Log in to continue your financial journey',
                style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Email Field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EMAIL OR PHONE',
              style: GoogleFonts.ibmPlexMono(
                color: AppTheme.sage,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.06,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppTheme.line),
              ),
              child: Text(
                '${p.name.toLowerCase().replaceAll(' ', '')}@example.com',
                style: const TextStyle(fontSize: 13, color: AppTheme.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        // Password Field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PASSWORD',
              style: GoogleFonts.ibmPlexMono(
                color: AppTheme.sage,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.06,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppTheme.line),
              ),
              child: const Text(
                '••••••••••',
                style: TextStyle(fontSize: 13, color: AppTheme.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Text(
              'Forgot password?',
              style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // CTA Log in
        ElevatedButton(
          onPressed: () => vm.setScreen('dashboard'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.ink,
            elevation: 0,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('Log in', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        ),
        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: [
              const Expanded(child: Divider(color: AppTheme.line)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('or', style: GoogleFonts.ibmPlexMono(color: AppTheme.sage, fontSize: 10.5)),
              ),
              const Expanded(child: Divider(color: AppTheme.line)),
            ],
          ),
        ),
        // Sandbox Button
        ElevatedButton(
          onPressed: () => vm.setScreen('onboard'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.gold,
            elevation: 0,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('Try sandbox free — no signup', style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 14),
        // Trial Badge
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.paperAlt,
            border: Border.all(color: AppTheme.gold, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: AppTheme.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '14-day sandbox trial',
                      style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Full access to the AI advisor, expense tracker and investment simulator with mock funds. No card, no commitment.',
                      style: GoogleFonts.ibmPlexSans(fontSize: 10.5, color: const Color(0xFF5A655E), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('New here? ', style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 11.5)),
            GestureDetector(
              onTap: () => vm.setScreen('signup'),
              child: Text(
                'Create an account',
                style: GoogleFonts.ibmPlexSans(color: AppTheme.ink, fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
