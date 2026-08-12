import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/app_viewmodel.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final p = vm.currentPersona;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Text(
          'Create your account',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 23),
        ),
        const SizedBox(height: 2),
        Text(
          'Takes about a minute',
          style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 12),
        ),
        const SizedBox(height: 16),
        // Full Name
        _buildField('Full name', 'e.g. ${p.name}'),
        const SizedBox(height: 13),
        _buildField('Email', 'you@example.com', isPlaceholder: true),
        const SizedBox(height: 13),
        _buildField('Phone', '07X XXX XXXX', isPlaceholder: true),
        const SizedBox(height: 13),
        _buildField('Password', 'Create a password', isPlaceholder: true),
        const SizedBox(height: 14),
        // I am a...
        Text(
          'I AM A...',
          style: GoogleFonts.ibmPlexMono(
            color: AppTheme.sage,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: vm.personas.entries.map((entry) {
            final active = entry.key == vm.currentPersonaId;
            return GestureDetector(
              onTap: () => vm.setPersona(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? AppTheme.ink : AppTheme.white,
                  border: Border.all(color: active ? AppTheme.ink : AppTheme.line),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  entry.value.role.split(' · ')[0],
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: active ? AppTheme.white : AppTheme.text,
                  ),
                ),
              ),
            );
          }).toList(),
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
                      'Start with the sandbox — checked by default',
                      style: GoogleFonts.ibmPlexSans(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Practice investing and get AI guidance risk-free for 14 days before linking real accounts.',
                      style: GoogleFonts.ibmPlexSans(fontSize: 10.5, color: const Color(0xFF5A655E), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Create Account CTA
        ElevatedButton(
          onPressed: () => vm.setScreen('onboard'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.ink,
            elevation: 0,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('Create account', style: TextStyle(color: AppTheme.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account? ', style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 11.5)),
            GestureDetector(
              onTap: () => vm.setScreen('login'),
              child: Text(
                'Log in',
                style: GoogleFonts.ibmPlexSans(color: AppTheme.ink, fontWeight: FontWeight.bold, fontSize: 11.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildField(String label, String value, {bool isPlaceholder = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
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
            value,
            style: TextStyle(
              fontSize: 13, 
              color: isPlaceholder ? const Color(0xFF9AA39C) : AppTheme.text,
            ),
          ),
        ),
      ],
    );
  }
}
