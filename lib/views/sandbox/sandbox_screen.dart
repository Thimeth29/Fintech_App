// lib/views/sandbox/sandbox_screen.dart
//
// Practice with the Sandbox: fully usable without logging in. Both the
// welcome screen's "TRY SandBox" button and the home screen's "Sandbox"
// block push this exact same screen/view model, per the app spec.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/gradient_scaffold.dart';
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
        title: Text('${isBuy ? "Buy" : "Sell"} ${instrument.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: LKR ${instrument.currentPrice.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(controller.text) ?? 0;
              final success = isBuy ? vm.buy(instrument, qty) : vm.sell(instrument, qty);
              Navigator.pop(dialogContext);
              if (!success && vm.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(vm.errorMessage!)),
                );
              }
            },
            child: Text(isBuy ? 'Buy' : 'Sell'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SandboxViewModel(),
      child: GradientScaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('Practice with the Sandbox')),
        body: Consumer<SandboxViewModel>(
          builder: (context, vm, _) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Virtual Balance', style: TextStyle(fontSize: 14)),
                  Text(
                    'LKR ${vm.virtualBalance.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Portfolio value: LKR ${vm.portfolioValue.toStringAsFixed(2)}  '
                    '(${vm.totalReturnPercent >= 0 ? "+" : ""}${vm.totalReturnPercent.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      color: vm.totalReturnPercent >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Instruments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: vm.instruments.length,
                      itemBuilder: (context, index) {
                        final instrument = vm.instruments[index];
                        return Card(
                          child: ListTile(
                            title: Text(instrument.name),
                            subtitle: Text(
                              '${instrument.type} · LKR ${instrument.currentPrice.toStringAsFixed(2)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => _showTradeDialog(context, instrument, true),
                                  child: const Text('Buy'),
                                ),
                                TextButton(
                                  onPressed: () => _showTradeDialog(context, instrument, false),
                                  child: const Text('Sell'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
