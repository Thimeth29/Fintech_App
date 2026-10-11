import 'package:flutter/foundation.dart';
import '../core/utils/money.dart';
import '../models/debt_model.dart';
import '../services/finance_data_services.dart';

class DebtsViewModel extends ChangeNotifier {
  final DebtService _service = DebtService();

  /// Clock, overridable in tests.
  DateTime Function() now = DateTime.now;

  String? _userId;
  bool isLoading = false;
  String? errorMessage;
  List<Debt> debts = [];

  bool get isLoggedIn => (_userId ?? '').isNotEmpty;

  List<Debt> get lent => debts.where((d) => d.direction == Debt.lent).toList();
  List<Debt> get borrowed => debts.where((d) => d.direction == Debt.borrowed).toList();

  /// Total still owed to me / by me on open debts.
  double get owedToMe => lent.where((d) => d.isOpen).fold(0.0, (s, d) => s + d.outstanding);
  double get owedByMe => borrowed.where((d) => d.isOpen).fold(0.0, (s, d) => s + d.outstanding);

  List<Debt> get overdue => debts.where((d) => d.isOverdue(now())).toList();

  /// Open debts due within 7 days or already overdue, soonest first.
  List<Debt> get reminders => debts.where((d) => d.isDueWithin(now(), 7)).toList()
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

  /// One-line reminder for Home's "Suggested for you", or null.
  String? get reminderText {
    final r = reminders;
    if (r.isEmpty) return null;
    final d = r.first;
    final today = dateOnly(now());
    final days = d.dueDate!.difference(today).inDays;
    final when = days < 0
        ? 'was due ${-days} day${days == -1 ? '' : 's'} ago'
        : days == 0
            ? 'is due today'
            : 'is due in $days day${days == 1 ? '' : 's'}';
    final what = d.isLent
        ? '${d.personName} owes you ${formatRs(d.outstanding)}'
        : 'You owe ${d.personName} ${formatRs(d.outstanding)}';
    final more = r.length > 1 ? ' (+${r.length - 1} more)' : '';
    return '$what — it $when.$more';
  }

  @visibleForTesting
  void seedForTest({required String userId, List<Debt> debts = const []}) {
    _userId = userId;
    this.debts = [...debts];
    notifyListeners();
  }

  Future<void> load(String userId) async {
    _userId = userId;
    if (userId.isEmpty) {
      debts = [];
      notifyListeners();
      return;
    }
    isLoading = true;
    notifyListeners();
    try {
      debts = await _service.fetchDebts(userId);
      errorMessage = null;
    } catch (_) {
      errorMessage = 'Could not load debts.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addDebt(Debt debt) async {
    if (!isLoggedIn) return false;
    try {
      final saved = await _service.addDebt(debt);
      if (saved == null) return false;
      debts = [saved, ...debts];
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not save debt.';
      notifyListeners();
      return false;
    }
  }

  /// Records a (partial) repayment. Rejected when it exceeds what's
  /// outstanding; settles the debt automatically at zero.
  Future<bool> recordPayment(Debt debt, {required double amount, DateTime? on, String? note}) async {
    if (!isLoggedIn || debt.id == null) return false;
    if (amount <= 0) {
      errorMessage = 'Enter an amount greater than zero.';
      notifyListeners();
      return false;
    }
    if (amount > debt.outstanding + 0.005) {
      errorMessage = 'That is more than the ${formatRs(debt.outstanding)} outstanding.';
      notifyListeners();
      return false;
    }
    try {
      final saved = await _service.addPayment(DebtPayment(
        debtId: debt.id!,
        userId: _userId!,
        amount: amount,
        paidOn: on ?? now(),
        note: note,
      ));
      if (saved == null) return false;
      var updated = debt.copyWith(payments: [saved, ...debt.payments]);
      // Mirrors the database trigger so the screen updates without a reload.
      if (updated.outstanding <= 0) updated = updated.copyWith(status: Debt.settled);
      debts = [for (final d in debts) d.id == debt.id ? updated : d];
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not record payment.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setSettled(Debt debt, bool settled) async {
    if (debt.id == null) return false;
    final status = settled ? Debt.settled : Debt.open;
    try {
      await _service.setStatus(debt.id!, status);
      debts = [for (final d in debts) d.id == debt.id ? d.copyWith(status: status) : d];
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not update debt.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteDebt(Debt debt) async {
    if (debt.id == null) return false;
    try {
      await _service.deleteDebt(debt.id!);
      debts = debts.where((d) => d.id != debt.id).toList();
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not delete debt.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deletePayment(Debt debt, DebtPayment p) async {
    if (p.id == null) return false;
    try {
      await _service.deletePayment(p.id!);
      var updated = debt.copyWith(payments: debt.payments.where((x) => x.id != p.id).toList());
      if (updated.outstanding > 0 && !updated.isOpen) updated = updated.copyWith(status: Debt.open);
      debts = [for (final d in debts) d.id == debt.id ? updated : d];
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not delete payment.';
      notifyListeners();
      return false;
    }
  }
}
