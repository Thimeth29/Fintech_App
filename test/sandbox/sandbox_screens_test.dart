// Logged-in trainer screens with an in-memory stand-in for the Supabase
// RPCs: layouts at phone and desktop widths, local validation, and Home's
// sandbox card updating after a trade without a reload.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:my_app/core/sandbox/sandbox_config.dart';
import 'package:my_app/core/theme/app_theme.dart';
import 'package:my_app/models/sandbox_models.dart';
import 'package:my_app/services/sandbox/anchor_service.dart';
import 'package:my_app/services/sandbox/fast_forward.dart';
import 'package:my_app/services/sandbox/live_price_source.dart';
import 'package:my_app/services/sandbox/price_source.dart';
import 'package:my_app/services/sandbox_service.dart';
import 'package:my_app/viewmodels/sandbox_viewmodel.dart';
import 'package:my_app/views/sandbox/module_screen.dart';
import 'package:my_app/views/sandbox/sandbox_screen.dart';

String _iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Mirrors the server's checks for the calls the screens make.
class FakeSandboxService extends SandboxService {
  final Map<String, Map<String, dynamic>> wallets = {};
  final List<Map<String, dynamic>> holdings = [];
  int calls = 0;

  FakeSandboxService() {
    for (final m in SandboxModule.values) {
      wallets[m.id] = {
        'id': 'w-${m.id}',
        'module': m.id,
        'balance': 100000,
        // A Wednesday: the CSE simulator closes on sim weekends.
        'sim_date': '2026-10-14',
        'start_date': '2026-10-14',
        'price_anchors': <String, double>{},
        'reset_count': 0,
        'current_reset_batch': 'b1',
      };
    }
  }

  @override
  String? get userId => 'test-user';

  @override
  Future<SandboxSnapshot> load() async => SandboxSnapshot(
        wallets: wallets.values.map(SandboxWallet.fromJson).toList(),
        holdings: holdings.map(SandboxHolding.fromJson).toList(),
        positions: const [],
        progress: const SandboxProgress(xp: 120, level: 2, streak: 3),
        lessons: const [],
        badges: const {},
        challenges: const [],
        recentTrades: const [],
      );

  @override
  Future<SandboxWallet> unlockModule(SandboxModule m, Map<String, double> anchors) async {
    final w = wallets[m.id]!;
    w['price_anchors'] = {...anchors, ...(w['price_anchors'] as Map<String, double>)};
    return SandboxWallet.fromJson(w);
  }

  @override
  Future<Map<String, dynamic>> trade({
    required SandboxModule module,
    required InstrumentSpec spec,
    required String side,
    required double quantity,
    required double price,
    required double fee,
    double? stopLoss,
    double? takeProfit,
    String? note,
  }) async {
    calls++;
    if (quantity <= 0) throw const SandboxException('invalid_quantity');
    final w = wallets[module.id]!;
    final cost = price * quantity + fee;
    if (side != 'buy') throw const SandboxException('invalid_side');
    if ((w['balance'] as num) < cost) throw const SandboxException('insufficient_balance');
    w['balance'] = (w['balance'] as num) - cost;
    final h = {
      'id': 'h-${spec.symbol}',
      'module': module.id,
      'symbol': spec.symbol,
      'name': spec.name,
      'instrument_type': spec.type,
      'direction': 'long',
      'quantity': quantity,
      'average_price': price,
      'total_fees': fee,
      'opened_sim_date': w['sim_date'],
    };
    holdings
      ..removeWhere((x) => x['symbol'] == spec.symbol)
      ..add(h);
    return {'wallet': w, 'holding': h, 'trade_id': 't$calls', 'realised_pnl': null};
  }

  @override
  Future<Map<String, dynamic>> challengeProgress(String id, int progress, int target) async =>
      {'challenge': {'challenge_id': id, 'progress': progress, 'target': target}};

  @override
  Future<Map<String, dynamic>> awardBadge(String id) async => {'new_badge': true};

  @override
  Future<Map<String, dynamic>> awardHabitXp(String reason, int amount) async => {};

  @override
  Future<Map<String, dynamic>> fastForward(SandboxModule m, int days, List<SimEvent> events) async {
    final w = wallets[m.id]!;
    w['sim_date'] = _iso(addDays(parseSimDate(w['sim_date'])!, days));
    return {'wallet': w};
  }

  @override
  Future<List<SandboxTrade>> fetchTrades(SandboxModule module, {int limit = 300}) async => const [];
}

class FakeAnchors extends SandboxAnchorService {
  @override
  Future<Map<String, double>> anchorsFor(SandboxModule m) async => switch (m) {
        SandboxModule.cse => {for (final i in kCseInstruments) i.symbol: i.fallbackPrice},
        SandboxModule.gold => {for (final i in kGoldInstruments) i.symbol: 24800.0},
        SandboxModule.trading => {for (final i in kTradingInstruments) i.symbol: i.fallbackPrice},
        SandboxModule.fd => {
            for (final b in kFdFallbackRates.entries)
              for (final t in b.value.entries) fdAnchorKey(b.key, t.key): t.value,
          },
        SandboxModule.govSecurities => {
            for (final e in kTbillFallbackYields.entries) tbillAnchorKey(e.key): e.value,
            for (final e in kTbondFallbackYields.entries) tbondAnchorKey(e.key): e.value,
          },
        SandboxModule.forex => {for (final i in kForexInstruments) i.symbol: i.fallbackPrice},
        SandboxModule.communityFund => <String, double>{},
      };
}

/// market_prices as the scraper would leave them, without Supabase.
class FakeMarket implements MarketPriceRepository {
  final List<MarketPriceRow> rows;
  FakeMarket(this.rows);
  @override
  Future<List<MarketPriceRow>> fetchLatest() async => rows;
  @override
  Future<Map<String, List<PricePoint>>> fetchHistory(Iterable<String> symbols, DateTime since) async => const {};
  @override
  Future<void> Function() watch(void Function(MarketPriceRow row) onRow) => () async {};
}

Future<SandboxViewModel> _loadedVm() async {
  final vm = SandboxViewModel(service: FakeSandboxService(), anchors: FakeAnchors(), listenToAuth: false);
  await vm.load();
  return vm;
}

Widget _app(SandboxViewModel vm, Widget home) => ChangeNotifierProvider.value(
      value: vm,
      child: MaterialApp(theme: AppTheme.lightTheme, home: home),
    );

/// Same approach as layout_overflow_test.dart: real Roboto metrics instead
/// of the square test font, so text widths are realistic.
Future<void> _loadRealisticFont() async {
  final engineDir = File(Platform.resolvedExecutable).parent;
  final fontsDir = Directory('${engineDir.parent.parent.path}${Platform.pathSeparator}material_fonts');
  if (!fontsDir.existsSync()) return;
  const faces = {
    '100': 'thin', '200': 'light', '300': 'light', 'regular': 'regular',
    '500': 'medium', '600': 'bold', '700': 'bold', '800': 'black', '900': 'black',
  };
  for (final e in faces.entries) {
    final file = File('${fontsDir.path}${Platform.pathSeparator}roboto-${e.value}.ttf');
    if (!file.existsSync()) continue;
    for (final family in const ['Poppins', 'Inter']) {
      final loader = FontLoader('${family}_${e.key}')
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await loader.load();
    }
  }
}

/// Collects overflow errors with the lib/ location that caused them.
List<String> _captureOverflows() {
  final found = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(details.toString(minLevel: DiagnosticLevel.info));
      found.add('${text.split('\n').first} @ ${where?.group(0) ?? '?'}');
    } else {
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
  return found;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadRealisticFont);

  test('view model rejects zero and negative quantities before calling the server', () async {
    final service = FakeSandboxService();
    final vm = SandboxViewModel(service: service, anchors: FakeAnchors(), listenToAuth: false);
    await vm.load();
    for (final q in [0.0, -5.0, double.nan]) {
      final res = await vm.trade(spec: kCseInstruments.first, side: 'buy', quantity: q);
      expect(res.ok, isFalse);
      expect(res.error, contains('greater than zero'));
    }
    final frac = await vm.trade(spec: kCseInstruments.first, side: 'buy', quantity: 1.5);
    expect(frac.ok, isFalse);
    expect(service.calls, 0);
  });

  test('a failed trade leaves local state untouched (no optimistic success)', () async {
    final vm = await _loadedVm();
    final before = vm.balance(SandboxModule.cse);
    final res = await vm.trade(spec: kCseInstruments.first, side: 'buy', quantity: 1000000);
    expect(res.ok, isFalse);
    expect(vm.balance(SandboxModule.cse), before);
    expect(vm.holdings, isEmpty);
  });

  test('totals add every module and the % compares against Rs 100,000 per module', () async {
    final vm = await _loadedVm();
    final modules = SandboxModule.values.length;
    expect(vm.startingTotal, kSandboxStartingBalance * modules);
    expect(vm.totalValue, closeTo(kSandboxStartingBalance * modules, 0.01));
    final res = await vm.trade(spec: kCseInstruments.first, side: 'buy', quantity: 100);
    expect(res.ok, isTrue);
    final fee = vm.holdings.single.totalFees;
    // Bought at today's price, so only the fee has been lost so far.
    expect(vm.totalValue, closeTo(kSandboxStartingBalance * modules - fee, 0.01));
    expect(vm.allocationByType['stock'], greaterThan(0));
  });

  test('live prices drive quotes; fast-forward only where prices are simulated', () async {
    final now = DateTime.now();
    final vm = SandboxViewModel(
      service: FakeSandboxService(),
      anchors: FakeAnchors(),
      market: FakeMarket([
        MarketPriceRow(symbol: 'JKH.N', kind: 'stock', name: 'JKH', price: 21.4, unit: 'LKR', source: 'CSE', asOf: now),
        MarketPriceRow(symbol: 'USDLKR', kind: 'forex', name: 'USD', price: 301.5, unit: 'LKR', source: 'CBSL', asOf: now),
      ]),
      priceMode: PriceMode.live,
      listenToAuth: false,
    );
    await vm.load();
    await vm.setPriceMode(PriceMode.simulated);
    await vm.setPriceMode(PriceMode.live); // starts the live source
    await Future<void>.delayed(Duration.zero);

    final jkh = kCseInstruments.first;
    expect(vm.isLivePrice(jkh), isTrue);
    expect(vm.priceOf(jkh), 21.4);
    expect(vm.quoteTrade(jkh, 'buy', 10).price, 21.4);
    expect(vm.isLivePrice(kCseInstruments[1]), isFalse); // not scraped: simulated
    expect(vm.priceOf(kForexInstruments.first), 301.5);
    expect(vm.canFastForward(SandboxModule.cse), isFalse);
    expect(vm.canFastForward(SandboxModule.forex), isFalse);
    expect(vm.canFastForward(SandboxModule.fd), isTrue); // rates lock in, so term modules still fast-forward
    expect(vm.canFastForward(SandboxModule.communityFund), isTrue);
    expect((await vm.fastForward(SandboxModule.cse, 1)).ok, isFalse);

    await vm.setPriceMode(PriceMode.simulated);
    expect(vm.isLivePrice(jkh), isFalse);
    expect(vm.priceOf(jkh), closeTo(jkh.fallbackPrice, 1e-9));
    expect(vm.canFastForward(SandboxModule.cse), isTrue);

    // A buy uses the price the source gave, through the same engine.
    await vm.setPriceMode(PriceMode.live);
    final res = await vm.trade(spec: jkh, side: 'buy', quantity: 100);
    expect(res.ok, isTrue);
    expect(vm.holdingOf(jkh)!.averagePrice, 21.4);
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('hub renders logged in @ ${width.toInt()}px without overflow', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final overflows = _captureOverflows();
      final vm = await tester.runAsync(_loadedVm);
      await tester.pumpWidget(_app(vm!, const SandboxScreen()));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(overflows, isEmpty, reason: overflows.join('\n'));
      expect(tester.takeException(), isNull);
      expect(find.text('VIRTUAL NET WORTH'), findsOneWidget);
      expect(find.text('CSE Stock Investing'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    for (final m in SandboxModule.values) {
      testWidgets('${m.id} practise tab @ ${width.toInt()}px renders without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final overflows = _captureOverflows();
        final vm = await tester.runAsync(_loadedVm);
        await tester.pumpWidget(_app(vm!, ModuleScreen(module: m, initialTab: ModuleTab.practise)));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(overflows, isEmpty, reason: overflows.join('\n'));
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Simulated'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 5));
      });
    }
  }

  testWidgets('trade sheet blocks a zero quantity in the UI', (tester) async {
    tester.view.physicalSize = const Size(414, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final vm = await tester.runAsync(_loadedVm);
    await tester.pumpWidget(_app(vm!, const ModuleScreen(module: SandboxModule.cse, initialTab: ModuleTab.practise)));
    await tester.pump(const Duration(milliseconds: 300));
    final buy = find.widgetWithText(ElevatedButton, 'Buy').first;
    await tester.ensureVisible(buy);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(buy);
    // The chart's marker pulses forever, so pump a fixed time, not settle.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(find.byType(TextField).first, '0');
    await tester.pump();
    final submit = find.widgetWithText(ElevatedButton, 'Enter a quantity');
    await tester.ensureVisible(submit);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Enter a quantity greater than zero.'), findsOneWidget);
    expect(vm.holdings, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a widget watching the shared view model updates after a trade', (tester) async {
    final vm = await tester.runAsync(_loadedVm);
    await tester.pumpWidget(_app(
      vm!,
      Builder(builder: (context) {
        final v = context.watch<SandboxViewModel>();
        return Text('total ${v.totalValue.toStringAsFixed(2)} holdings ${v.holdings.length}');
      }),
    ));
    final start = (kSandboxStartingBalance * SandboxModule.values.length).toStringAsFixed(2);
    expect(find.text('total $start holdings 0'), findsOneWidget);
    await tester.runAsync(() => vm.trade(spec: kCseInstruments.first, side: 'buy', quantity: 10));
    await tester.pump();
    expect(find.textContaining('holdings 1'), findsOneWidget);
  });
}
