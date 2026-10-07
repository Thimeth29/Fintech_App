import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Bar: Logo & Language Dropdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D653E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.show_chart_rounded,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'FinOps',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1D1E),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLanguage,
                            isDense: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 18, color: Color(0xFF1A1D1E)),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1D1E),
                            ),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedLanguage = val);
                              }
                            },
                            items: const [
                              DropdownMenuItem(
                                  value: 'English', child: Text('English')),
                              DropdownMenuItem(
                                  value: 'සිංහල', child: Text('සිංහල')),
                              DropdownMenuItem(
                                  value: 'தமிழ்', child: Text('தமிழ்')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Green Sandbox Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D653E),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SANDBOX PORTFOLIO',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3C06B),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Virtual money',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1D1E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Rs 100,000',
                          style: GoogleFonts.outfit(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Bar Chart Graphic
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildBar(34, const Color(0xFF3DA373)),
                            const SizedBox(width: 8),
                            _buildBar(54, const Color(0xFF3DA373)),
                            const SizedBox(width: 8),
                            _buildBar(40, const Color(0xFF3DA373)),
                            const SizedBox(width: 8),
                            _buildBar(72, const Color(0xFF3DA373)),
                            const SizedBox(width: 8),
                            _buildBar(90, const Color(0xFFF3C06B)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Headline & Description
                  Text(
                    'Grow your money with confidence',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1D1E),
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Track spending, practise investing risk-free, and get advice that tells you why.',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: const Color(0xFF5A6578),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Feature Highlights List
                  _buildFeatureRow(
                    Icons.star_outline_rounded,
                    'Practise with Rs 100,000 of virtual money',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(
                    Icons.help_outline_rounded,
                    'Every suggestion explains its reasons',
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureRow(
                    Icons.notes_rounded,
                    'Learn in Sinhala, Tamil or English',
                  ),
                  const SizedBox(height: 36),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D653E),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Get started',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'I already have an account',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1D1E),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(double height, Color color) {
    return Expanded(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEBF4EE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF0D653E), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1D1E),
            ),
          ),
        ),
      ],
    );
  }
}
