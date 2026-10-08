import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';
import '../../models/instrument_model.dart';
import '../../viewmodels/sandbox_viewmodel.dart';

class SandboxScreen extends StatelessWidget {
  const SandboxScreen({super.key});

  void _showTradeDialog(BuildContext context, Instrument instrument, bool isBuy) {
    final controller = TextEditingController();
    final vm = context.read<SandboxViewModel>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '${isBuy ? "Buy" : "Sell"} ${instrument.name}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Price: Rs ${instrument.currentPrice.toStringAsFixed(2)}',
              style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: GoogleFonts.outfit(color: AppColors.textDark),
              decoration: InputDecoration(
                labelText: 'Quantity of Units',
                labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                hintText: 'e.g. 100',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isBuy ? AppColors.primary : AppColors.rose,
            ),
            onPressed: () async {
              final qty = double.tryParse(controller.text) ?? 0;
              final success = isBuy ? await vm.buy(instrument, qty) : await vm.sell(instrument, qty);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (!success && vm.errorMessage != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(vm.errorMessage!, style: GoogleFonts.outfit()),
                    backgroundColor: AppColors.roseDark,
                  ),
                );
              }
            },
            child: Text(isBuy ? 'Confirm Purchase' : 'Confirm Sale', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SandboxViewModel()..loadSandboxData(),
      child: GradientScaffold(
        maxContentWidth: 860,
        appBar: AppBar(
          leading: Container(
            margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight),
            ),
            child: const BackButton(color: AppColors.textDark),
          ),
          title: Text(
            'Sandbox Investment Trainer',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
        ),
        body: Consumer<SandboxViewModel>(
          builder: (context, vm, _) {
            final isPositive = vm.totalReturnPercent >= 0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Portfolio Hero Card
                  GlassCard(
                    padding: const EdgeInsets.all(22),
                    gradient: AppGradients.heroCard,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'VIRTUAL SANDBOX PORTFOLIO',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white70,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Virtual Money',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Rs ${vm.virtualBalance.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              size: 16,
                              color: isPositive ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Portfolio Value: Rs ${vm.portfolioValue.toStringAsFixed(2)} '
                              '(${isPositive ? "+" : ""}${vm.totalReturnPercent.toStringAsFixed(2)}%)',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isPositive ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'Available Market Instruments',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 12),

                  // Instruments List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vm.instruments.length,
                    itemBuilder: (context, index) {
                      final instrument = vm.instruments[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.white,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: AppColors.mintBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getInstrumentIcon(instrument.type),
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      instrument.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${instrument.type} • Rs ${instrument.currentPrice.toStringAsFixed(2)}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _showTradeDialog(context, instrument, true),
                                    child: Text('Buy', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 6),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textDark,
                                      side: const BorderSide(color: AppColors.borderLight),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => _showTradeDialog(context, instrument, false),
                                    child: Text('Sell', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _getInstrumentIcon(String type) {
    if (type.contains('Stock') || type.contains('Equities')) return Icons.show_chart_rounded;
    if (type.contains('Bond') || type.contains('Treasury')) return Icons.account_balance_outlined;
    if (type.contains('Gold')) return Icons.monetization_on_outlined;
    return Icons.savings_outlined;
  }
}

