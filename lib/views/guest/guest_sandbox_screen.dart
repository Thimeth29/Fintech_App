// lib/views/guest/guest_sandbox_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/instrument_model.dart';
import '../../viewmodels/sandbox_viewmodel.dart';
import '../auth/login_screen.dart';

class GuestSandboxScreen extends StatelessWidget {
  const GuestSandboxScreen({super.key});

  void _showTradeDialog(
    BuildContext context,
    Instrument instrument,
    bool isBuy,
  ) {
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
              final success = isBuy
                  ? vm.buy(instrument, qty)
                  : vm.sell(instrument, qty);
              Navigator.pop(dialogContext);
              if (!success && vm.errorMessage != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
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
    final vm = context.watch<SandboxViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sandbox Investment (Guest Mode)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('Sign In', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Virtual Balance',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            Text(
              'LKR ${vm.virtualBalance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Portfolio value: LKR ${vm.portfolioValue.toStringAsFixed(2)}  '
              '(${vm.totalReturnPercent >= 0 ? "+" : ""}${vm.totalReturnPercent.toStringAsFixed(2)}%)',
              style: TextStyle(
                color: vm.totalReturnPercent >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Instruments',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
                            onPressed: () =>
                                _showTradeDialog(context, instrument, true),
                            child: const Text('Buy'),
                          ),
                          TextButton(
                            onPressed: () =>
                                _showTradeDialog(context, instrument, false),
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
      ),
    );
  }
}
