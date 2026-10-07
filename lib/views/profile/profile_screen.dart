import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import '../../models/profile_model.dart';
import '../auth/welcome_screen.dart';

final _sampleProfile = ProfileModel(
  id: 'sample',
  name: 'Samantha Perera',
  email: 'samantha@mail.com',
  mobile: '+94 77 123 4567',
);

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 760,
      appBar: const TopNavBar(
        current: AppSection.profile,
        title: 'My Profile',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          // Avatar Header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.mintBg,
                    child: Text(
                      _sampleProfile.name.isNotEmpty ? _sampleProfile.name[0] : '?',
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _sampleProfile.name,
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                Text(
                  _sampleProfile.email,
                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.mintBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Financial Literacy Rank: Pro Investor',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Personal Details',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
          ),
          const SizedBox(height: 10),

          _InfoTile(icon: Icons.person_outline_rounded, label: 'Full Name', value: _sampleProfile.name),
          _InfoTile(icon: Icons.email_outlined, label: 'Email Address', value: _sampleProfile.email),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Mobile Contact',
            value: _sampleProfile.mobile ?? 'Not set',
          ),

          const SizedBox(height: 24),
          Text(
            'Preferences & Security',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textDark),
          ),
          const SizedBox(height: 10),

          const GlassCard(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            backgroundColor: Colors.white,
            child: Column(
              children: [
                _SettingsRow(icon: Icons.lock_outline_rounded, label: 'Change Password & Security'),
                Divider(height: 1, color: AppColors.borderLight),
                _SettingsRow(icon: Icons.notifications_outlined, label: 'Push Notifications'),
                Divider(height: 1, color: AppColors.borderLight),
                _SettingsRow(icon: Icons.auto_awesome_outlined, label: 'AI Advisor Customizations'),
                Divider(height: 1, color: AppColors.borderLight),
                _SettingsRow(icon: Icons.privacy_tip_outlined, label: 'Privacy & Data Governance'),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.rose),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text('Log out of account', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: Colors.white,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.mintBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 1),
                  Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SettingsRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Icon(icon, color: AppColors.textDark, size: 20),
      title: Text(label, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textDark, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
      onTap: () {},
    );
  }
}


