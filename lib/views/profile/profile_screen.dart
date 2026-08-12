import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/app_viewmodel.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppViewModel>();
    final p = vm.currentPersona;
    final primaryColor = Color(int.parse(p.color.replaceAll('#', '0xFF')));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Profile Hero
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 33,
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
              const SizedBox(height: 10),
              Text(
                p.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 23),
              ),
              const SizedBox(height: 2),
              Text(
                p.role,
                style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Stat Strip
        Row(
          children: [
            _buildStatBox('${p.quiz.split('%')[0].split(' ').last}%', 'Literacy score'),
            const SizedBox(width: 8),
            _buildStatBox('12', 'Week streak'),
            const SizedBox(width: 8),
            _buildStatBox('Trial', 'Sandbox plan'),
          ],
        ),
        const SizedBox(height: 16),
        // Account Settings List
        _buildSectionLabel('ACCOUNT'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSettingsItem(icon: Icons.person_outline, name: 'Personal details', sub: 'Name, email, phone'),
              _buildSettingsItem(icon: Icons.language_outlined, name: 'Language', sub: 'English'),
              _buildSettingsItem(icon: Icons.account_balance_outlined, name: 'Linked accounts', sub: 'None linked — sandbox mode'),
              _buildSettingsItem(icon: Icons.notifications_none_outlined, name: 'Notifications', sub: 'Predictions, advisor alerts'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Data & Privacy Settings List
        _buildSectionLabel('DATA & PRIVACY'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            border: Border.all(color: AppTheme.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSettingsItem(icon: Icons.security_outlined, name: 'Security & encryption', sub: 'Data encrypted at rest and in transit'),
              _buildSettingsItem(icon: Icons.delete_outline, name: 'Delete my data', sub: 'Full right to deletion, anytime'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Log out CTA
        OutlinedButton(
          onPressed: () => vm.setScreen('login'),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.ink),
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('Log out', style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.white,
          border: Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.newsreader(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.ink),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.ibmPlexMono(
        fontSize: 10.5,
        letterSpacing: 0.08,
        color: AppTheme.sage,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String name,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.line, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.ink, size: 17),
              const SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.text)),
                  const SizedBox(height: 2),
                  Text(sub, style: GoogleFonts.ibmPlexSans(color: AppTheme.sage, fontSize: 10)),
                ],
              )
            ],
          ),
          const Icon(Icons.chevron_right, color: AppTheme.sage, size: 14),
        ],
      ),
    );
  }
}
