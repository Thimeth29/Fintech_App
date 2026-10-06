// lib/views/profile/profile_screen.dart
//
// Pure UI for now — shows a static sample ProfileModel. Wiring this up to
// the real signed-in user's profile row happens in the backend phase.
import 'package:flutter/material.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/glass_card.dart';
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
      appBar: const TopNavBar(
        current: AppSection.profile,
        title: 'My Profile',
        showBackButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white,
              child: Text(
                _sampleProfile.name.isNotEmpty ? _sampleProfile.name[0] : '?',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _sampleProfile.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          Center(
            child: Text(
              _sampleProfile.email,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),
          const SizedBox(height: 28),
          _InfoTile(icon: Icons.person_outline, label: 'Name', value: _sampleProfile.name),
          _InfoTile(icon: Icons.email_outlined, label: 'Email', value: _sampleProfile.email),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Mobile',
            value: _sampleProfile.mobile ?? 'Not set',
          ),
          const SizedBox(height: 20),
          const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const GlassCard(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                _SettingsRow(icon: Icons.lock_outline, label: 'Change password'),
                Divider(height: 1),
                _SettingsRow(icon: Icons.notifications_outlined, label: 'Notifications'),
                Divider(height: 1),
                _SettingsRow(icon: Icons.privacy_tip_outlined, label: 'Privacy'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Log out'),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (route) => false,
              );
            },
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.black87),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {},
    );
  }
}
