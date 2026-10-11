import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../community/community_screen.dart';
import '../auth/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthViewModel>().loadUserProfile();
    });
  }

  void _showEditProfileDialog(BuildContext context, AuthViewModel authVm) {
    final profile = authVm.userProfile ?? {};
    final nameController = TextEditingController(text: profile['full_name'] ?? authVm.displayName);
    final occupationController = TextEditingController(text: profile['occupation'] ?? 'Employed');
    String district = profile['district'] ?? 'Colombo';
    String role = profile['user_role'] ?? 'App User / Citizen';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.deepNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Profile Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.onGlass),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: GoogleFonts.outfit(color: AppColors.onGlassMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: occupationController,
                decoration: InputDecoration(
                  labelText: 'Occupation',
                  labelStyle: GoogleFonts.outfit(color: AppColors.onGlassMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: district,
                decoration: InputDecoration(
                  labelText: 'District',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Colombo', child: Text('Colombo')),
                  DropdownMenuItem(value: 'Gampaha', child: Text('Gampaha')),
                  DropdownMenuItem(value: 'Kandy', child: Text('Kandy')),
                  DropdownMenuItem(value: 'Galle', child: Text('Galle')),
                  DropdownMenuItem(value: 'Jaffna', child: Text('Jaffna')),
                  DropdownMenuItem(value: 'Kurunegala', child: Text('Kurunegala')),
                ],
                onChanged: (val) => district = val ?? district,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.onGlassMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await authVm.updateProfile({
                'full_name': nameController.text.trim(),
                'occupation': occupationController.text.trim(),
                'district': district,
                'user_role': role,
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Profile updated successfully!', style: GoogleFonts.outfit()),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: Text('Save Changes', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authVm, _) {
        final profile = authVm.userProfile ?? {};
        final name = (profile['full_name'] as String?) ?? (authVm.displayName.isNotEmpty ? authVm.displayName : 'User');
        final email = (profile['email'] as String?) ?? 'Not set';
        final mobile = (profile['mobile_number'] as String?) ?? 'Not set';
        final role = (profile['user_role'] as String?) ?? 'App User / Citizen';
        final occupation = (profile['occupation'] as String?) ?? 'Employed';
        final district = (profile['district'] as String?) ?? 'Colombo';
        final language = (profile['preferred_language'] as String?) ?? 'English';
        final literacyRank = (profile['financial_literacy_rank'] as String?) ?? 'Bronze Investor';

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
              // Avatar Header — translucent blue profile card, avatar with a
              // white ring.
              GlassCard(
                gradient: AppGradients.heroCard,
                borderColor: AppColors.glassBorderStrong,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.primaryDark,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.outfit(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onGlass),
                    ),
                    Text(
                      email,
                      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.onGlassMuted),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.innerFillSelected,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.glassBorderStrong),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded, color: AppColors.accentCyan, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Financial Literacy Rank: $literacyRank',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentCyan),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Personal Details',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.onGlass),
                  ),
                  TextButton.icon(
                    onPressed: () => _showEditProfileDialog(context, authVm),
                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.accentCyan),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accentCyan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              _InfoTile(icon: Icons.person_outline_rounded, label: 'Full Name', value: name),
              _InfoTile(icon: Icons.email_outlined, label: 'Email Address', value: email),
              _InfoTile(icon: Icons.phone_outlined, label: 'Mobile Contact', value: mobile),
              _InfoTile(icon: Icons.badge_outlined, label: 'User Role', value: role),
              _InfoTile(icon: Icons.work_outline_rounded, label: 'Occupation', value: occupation),
              _InfoTile(icon: Icons.location_on_outlined, label: 'District', value: district),
              _InfoTile(icon: Icons.language_outlined, label: 'Language', value: language),

              const SizedBox(height: 24),
              Text(
                'Preferences & Security',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.onGlass),
              ),
              const SizedBox(height: 10),

              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.groups_outlined,
                      label: 'Community profile & privacy',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CommunityScreen(initialTab: 3)),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    const _SettingsRow(icon: Icons.lock_outline_rounded, label: 'Change Password & Security'),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    const _SettingsRow(icon: Icons.notifications_outlined, label: 'Push Notifications'),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    const _SettingsRow(icon: Icons.auto_awesome_outlined, label: 'AI Advisor Customizations'),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    const _SettingsRow(icon: Icons.privacy_tip_outlined, label: 'Privacy & Data Governance')
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.loss),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: Text('Log out of account', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    await authVm.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.glassFillStrong,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.accentCyan),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.onGlassMuted)),
                  const SizedBox(height: 1),
                  Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onGlass)),
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
  final VoidCallback? onTap;

  const _SettingsRow({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Icon(icon, color: AppColors.onGlass, size: 20),
      title: Text(label, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.onGlass, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.onGlassMuted),
      onTap: onTap ?? () {},
    );
  }
}
