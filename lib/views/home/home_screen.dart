import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../bot/chat_screen.dart';
import '../sandbox/sandbox_screen.dart';
import '../expenditure/expenditure_screen.dart';
import '../expenditure/explore_plans_screen.dart';
import '../investments/asset_analytics_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthViewModel>().loadUserProfile();
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// "Nimal Perera" -> "NP"; falls back to "?" if there's nothing to show.
  String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final displayName = authVm.displayName.isNotEmpty ? authVm.displayName : 'there';
    final initials = _initialsOf(displayName == 'there' ? '' : displayName);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D653E),
        elevation: 4,
        icon: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
        label: Text(
          'Ask FinBot AI',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Header Bar
                  _buildHeaderBar(context, displayName, initials),
                  const SizedBox(height: 20),

                  // 2. October Spending Hero Card
                  _buildOctoberSpendingCard(),
                  const SizedBox(height: 20),

                  // 3. Quick Actions Row
                  _buildQuickActionsRow(context),
                  const SizedBox(height: 16),

                  // 3b. AI Coach Quick Shortcut Banner
                  _buildAiAssistantBanner(context),
                  const SizedBox(height: 20),

                  // 4. November Forecast Card
                  _buildNovemberForecastCard(),
                  const SizedBox(height: 20),

                  // 5. Budgets Card
                  _buildBudgetsCard(context),
                  const SizedBox(height: 20),

                  // 6. Emergency Fund Card
                  _buildEmergencyFundCard(),
                  const SizedBox(height: 20),

                  // 7. Suggested For You Card
                  _buildSuggestedCard(context),
                  const SizedBox(height: 20),

                  // 8. Sandbox Portfolio Card
                  _buildSandboxPortfolioCard(context),
                  const SizedBox(height: 20),

                  // 9. Market Today Card
                  _buildMarketTodayCard(context),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. TOP HEADER BAR
  // ==========================================
  Widget _buildHeaderBar(BuildContext context, String displayName, String initials) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF5A6578),
              ),
            ),
            Text(
              displayName,
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1D1E),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // Bell Notification Icon
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: Color(0xFF1A1D1E), size: 22),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Profile Avatar NP
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFF0D653E),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 2. OCTOBER SPENDING CARD
  // ==========================================
  Widget _buildOctoberSpendingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                'October spending',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              Text(
                '24 days left',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Rs 42,350',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'of Rs 65,000',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Custom Dual Color Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: 65,
                    child: Container(color: const Color(0xFFF3C06B)),
                  ),
                  Expanded(
                    flex: 35,
                    child: Container(color: const Color(0xFF147A4D)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bottom 3 Metrics Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricColumn('Income', 'Rs 85,000'),
              _buildMetricColumn('Budget left', 'Rs 22,650'),
              _buildMetricColumn('Saved', 'Rs 8,000'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 3. QUICK ACTIONS ROW
  // ==========================================
  Widget _buildQuickActionsRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionTile(
          context: context,
          icon: Icons.add_rounded,
          label: 'Add expense',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ExpenditureScreen()),
          ),
        ),
        _buildActionTile(
          context: context,
          icon: Icons.trending_up_rounded,
          label: 'Practise trade',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SandboxScreen()),
          ),
        ),
        _buildActionTile(
          context: context,
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Ask coach',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          ),
        ),
        _buildActionTile(
          context: context,
          icon: Icons.menu_book_rounded,
          label: 'Learn',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const ExploreExpenditurePlansScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(icon, color: const Color(0xFF0D653E), size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1D1E),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3b. AI COACH QUICK SHORTCUT BANNER
  // ==========================================
  Widget _buildAiAssistantBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEBF4EE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF0D653E).withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF0D653E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FinBot AI Financial Advisor',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1D1E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ask anything about CSE stocks, budgets or taxes',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5A6578),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0D653E), size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. NOVEMBER FORECAST CARD
  // ==========================================
  Widget _buildNovemberForecastCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'November forecast',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Average level',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Predicted from your last 5 months',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF5A6578),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Rs 61,800',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '73% of income',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF5A6578),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Monthly Columns Chart
          SizedBox(
            height: 115,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBarCol('Jun', 50, false),
                _buildBarCol('Jul', 65, false),
                _buildBarCol('Aug', 48, false),
                _buildBarCol('Sep', 68, false),
                _buildBarCol('Oct', 42, false, isSolidDark: true),
                _buildBarCol('Nov*', 76, true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF5A6578),
                height: 1.4,
              ),
              children: const [
                TextSpan(
                    text:
                        'Higher than October because school fees and festival shopping usually land in November. '),
                TextSpan(
                  text: 'Why?',
                  style: TextStyle(
                    color: Color(0xFF0D653E),
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarCol(String label, double height, bool isForecast,
      {bool isSolidDark = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 44,
          height: height,
          decoration: BoxDecoration(
            color: isSolidDark
                ? const Color(0xFF0D653E)
                : (isForecast ? Colors.transparent : const Color(0xFFC6E7D5)),
            borderRadius: BorderRadius.circular(8),
            border: isForecast
                ? Border.all(
                    color: const Color(0xFF0D653E),
                    width: 1.5,
                    style: BorderStyle.solid)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF718096),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 5. BUDGETS CARD
  // ==========================================
  Widget _buildBudgetsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budgets',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExpenditureScreen()),
                ),
                child: Text(
                  'See all',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D653E),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildBudgetItem('Food & groceries', 'Rs 15,600 / 20,000', 0.78,
              const Color(0xFF0D653E)),
          const SizedBox(height: 14),
          _buildBudgetItem(
              'Transport', 'Rs 5,200 / 10,000', 0.52, const Color(0xFF0D653E)),
          const SizedBox(height: 14),
          _buildBudgetItem('Bills & utilities', 'Rs 10,900 / 12,000', 0.91,
              const Color(0xFFDC2626),
              warningText: '91% used with 24 days to go'),
        ],
      ),
    );
  }

  Widget _buildBudgetItem(
      String label, String amountText, double ratio, Color color,
      {String? warningText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1D1E),
              ),
            ),
            Text(
              amountText,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: warningText != null ? color : const Color(0xFF5A6578),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (warningText != null) ...[
          const SizedBox(height: 4),
          Text(
            warningText,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ],
    );
  }

  // ==========================================
  // 6. EMERGENCY FUND CARD
  // ==========================================
  Widget _buildEmergencyFundCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emergency fund',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
              Text(
                '25%',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D653E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Rs 48,000 of Rs 195,000 goal - covers about 3 weeks',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF5A6578),
            ),
          ),
          const SizedBox(height: 12),

          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.25,
              minHeight: 6,
              backgroundColor: Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D653E)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Saving Rs 12,000 a month gets you to 3 months by next September.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF5A6578),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. SUGGESTED FOR YOU CARD
  // ==========================================
  Widget _buildSuggestedCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF0D653E), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUGGESTED FOR YOU',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0D653E),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Put part of your emergency fund in a 6-month fixed deposit',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1D1E),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Low risk, and the money is still within reach if you need it.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF5A6578),
            ),
          ),
          const SizedBox(height: 16),

          // Why this suggestion Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why this suggestion',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1D1E),
                  ),
                ),
                const SizedBox(height: 10),
                _buildReasonRow('Savings cover under 1 month', 0.9, 'Strong'),
                const SizedBox(height: 8),
                _buildReasonRow('Your goal: emergency fund', 0.9, 'Strong'),
                const SizedBox(height: 8),
                _buildReasonRow('You\'d wait if prices dropped', 0.6, 'Medium'),
                const SizedBox(height: 8),
                _buildReasonRow('Need the money in 1–5 years', 0.3, 'Small'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SandboxScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D653E),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Try it in sandbox',
                      style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AssetAnalyticsScreen(assetType: 'Fixed Deposit')),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Learn about FDs',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1D1E),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReasonRow(String label, double ratio, String statusText) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            label,
            style: GoogleFonts.outfit(
                fontSize: 12, color: const Color(0xFF4A5568)),
          ),
        ),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF0D653E)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            statusText,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D653E),
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 8. SANDBOX PORTFOLIO CARD
  // ==========================================
  Widget _buildSandboxPortfolioCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SandboxScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sandbox portfolio',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1D1E),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3C06B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Virtual',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1D1E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Rs 104,820',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1D1E),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '+4.8% since start',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D653E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Segmented Allocation Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                        flex: 45,
                        child: Container(color: const Color(0xFF1A1D1E))),
                    Expanded(
                        flex: 30,
                        child: Container(color: const Color(0xFF0D653E))),
                    Expanded(
                        flex: 25,
                        child: Container(color: const Color(0xFFF3C06B))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Allocation Legend Row
            Row(
              children: [
                _buildLegendItem('FD 45%', const Color(0xFF1A1D1E)),
                const SizedBox(width: 14),
                _buildLegendItem('CSE shares 30%', const Color(0xFF0D653E)),
                const SizedBox(width: 14),
                _buildLegendItem('Gold 25%', const Color(0xFFF3C06B)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5A6578),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 9. MARKET TODAY CARD
  // ==========================================
  Widget _buildMarketTodayCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Market today',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1D1E),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Mood: [Neutral]',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2x2 Market Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              _buildMarketTile('USD / LKR', 'Rs 302.50'),
              _buildMarketTile('Gold 22K (8g)', 'Rs 172,000'),
              _buildMarketTile('12-month FD', '9.80%'),
              _buildMarketTile('91-day T-bill', '9.50%'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'From CBSL and bank websites - updated today',
            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF718096)),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5A6578),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1D1E),
            ),
          ),
        ],
      ),
    );
  }
}
