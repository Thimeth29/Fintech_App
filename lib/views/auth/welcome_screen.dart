import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _selectedLanguage = 'English';

  static const Color _bg = AppColors.bgLight;
  static const Color _muted = AppColors.textMuted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _DoodlePainter())),
            LayoutBuilder(
              builder: (context, viewportConstraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: viewportConstraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Align(
                              alignment: Alignment.topRight,
                              child: _buildLanguageDropdown(),
                            ),
                            const Spacer(flex: 3),

                            // Logo tile
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: AppColors.borderLight),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.18),
                                    blurRadius: 26,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: Image.asset(
                                  'assets/branding/logo.jpg',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            Text(
                              'Welcome\nto FinOps',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 18),

                            Text(
                              'Smart money for Sri Lanka.\nPractise safe, grow confident.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: _muted,
                                height: 1.5,
                              ),
                            ),

                            const Spacer(flex: 4),

                            // Action Buttons
                            _buildActionButton(
                              label: 'Get started',
                              icon: Icons.arrow_forward_rounded,
                              filled: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SignupScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildActionButton(
                              label: 'I already have an account',
                              icon: Icons.login_rounded,
                              filled: false,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              ),
                            ),
                            const SizedBox(height: 18),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shield_outlined,
                                    size: 13, color: _muted),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Secured with row-level data protection',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLanguage,
          isDense: true,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.textDark),
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedLanguage = val);
            }
          },
          items: const [
            DropdownMenuItem(value: 'English', child: Text('English')),
            DropdownMenuItem(value: 'සිංහල', child: Text('සිංහල')),
            DropdownMenuItem(value: 'தமிழ்', child: Text('தமிழ்')),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppGradients.action,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 19),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.borderLight),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.textDark, size: 19),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Faint hand-drawn style scribbles scattered behind the headline, purely
/// decorative — mirrors the doodle background in the reference design.
class _DoodlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void circle(Offset center, double r) => canvas.drawCircle(center, r, paint);

    void plus(Offset c, double r) {
      canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), paint);
      canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), paint);
    }

    void zigzag(Offset start, double w, double h, int segments) {
      final path = Path()..moveTo(start.dx, start.dy);
      for (int i = 1; i <= segments; i++) {
        final x = start.dx + (w / segments) * i;
        final y = start.dy + (i.isOdd ? -h : h);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    void wave(Offset start, double w, double amp) {
      final path = Path()..moveTo(start.dx, start.dy);
      path.quadraticBezierTo(
          start.dx + w * 0.25, start.dy - amp, start.dx + w * 0.5, start.dy);
      path.quadraticBezierTo(
          start.dx + w * 0.75, start.dy + amp, start.dx + w, start.dy);
      canvas.drawPath(path, paint);
    }

    circle(Offset(size.width * 0.14, size.height * 0.32), 16);
    plus(Offset(size.width * 0.87, size.height * 0.27), 10);
    zigzag(Offset(size.width * 0.76, size.height * 0.42), 46, 10, 3);
    wave(Offset(size.width * 0.06, size.height * 0.48), 60, 10);
    circle(Offset(size.width * 0.90, size.height * 0.56), 8);
    plus(Offset(size.width * 0.15, size.height * 0.60), 7);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
