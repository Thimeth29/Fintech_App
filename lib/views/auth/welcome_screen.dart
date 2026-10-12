import 'package:flutter/material.dart';
import '../../core/theme/app_backgrounds.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_card.dart';
import 'signup_screen.dart';
import 'login_screen.dart';
import '../../core/theme/app_fonts.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _selectedLanguage = 'English';

  static Color get _muted => AppColors.onGlassMuted;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      kind: AppBackgroundKind.welcome,
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 440),
                                child: _buildHeroCard(),
                              ),
                              const Spacer(flex: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 440),
                                child: Column(
                                  children: [
                                    _buildActionButton(
                                      label: 'Get started',
                                      icon: Icons.arrow_forward_rounded,
                                      filled: true,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => const SignupScreen()),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildActionButton(
                                      label: 'I already have an account',
                                      icon: Icons.login_rounded,
                                      filled: false,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => const LoginScreen()),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shield_outlined, size: 13, color: _muted),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Secured with row-level data protection',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.text(
                                        fontSize: 11.5,
                                        color: _muted,
                                        shadows: kTitleShadow,
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
      ),
    );
  }

  /// Logo, headline and tagline on one glass card — the tagline needs the
  /// pane behind it to stay readable over the pale middle of the artwork.
  Widget _buildHeroCard() {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              color: AppColors.glassFillStrong,
              borderRadius: BorderRadius.circular(38),
              border: Border.all(color: AppColors.glassBorderStrong, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: 0.35),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.all(5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(33),
              child: Image.asset(
                'assets/branding/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.auto_graph_rounded,
                    color: Colors.white, size: 64),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'Welcome',
            textAlign: TextAlign.center,
            style: AppFonts.text(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: AppColors.onGlass,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Smart money for Sri Lanka.\nPractise safe, grow confident.',
            textAlign: TextAlign.center,
            style: AppFonts.text(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: _muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      borderRadius: 20,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedLanguage,
          isDense: true,
          dropdownColor: AppColors.deepNavy,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.onGlass),
          style: AppFonts.text(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.onGlass,
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
    final fg = filled ? AppColors.onLight : AppColors.onGlass;
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: fg, size: 19),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.text(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.onLight,
                elevation: 3,
                shadowColor: Colors.white.withValues(alpha: 0.25),
                shape: const StadiumBorder(),
              ),
              child: content,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.glassFill,
                foregroundColor: AppColors.onGlass,
                side: const BorderSide(color: AppColors.glassBorderStrong),
                shape: const StadiumBorder(),
              ),
              child: content,
            ),
    );
  }
}

/// Faint scribbles scattered behind the headline, purely decorative.
class _DoodlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
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
