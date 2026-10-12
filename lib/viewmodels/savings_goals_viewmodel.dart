import 'package:flutter/foundation.dart';
import '../models/savings_goal_model.dart';
import '../services/expenditure/goal_math.dart';
import '../services/finance_data_services.dart';

class SavingsGoalsViewModel extends ChangeNotifier {
  final SavingsGoalService _service = SavingsGoalService();

  /// Clock, overridable in tests.
  DateTime Function() now = DateTime.now;

  String? _userId;
  bool isLoading = false;
  String? errorMessage;
  List<SavingsGoal> goals = [];

  bool get isLoggedIn => (_userId ?? '').isNotEmpty;

  List<SavingsGoal> get activeGoals => goals.where((g) => g.status == SavingsGoal.active).toList();
  List<SavingsGoal> get completedGoals =>
      goals.where((g) => g.status == SavingsGoal.completed).toList();
  List<SavingsGoal> get archivedGoals =>
      goals.where((g) => g.status == SavingsGoal.archived).toList();

  GoalProgress progressOf(SavingsGoal g) => computeGoalProgress(g, now());

  List<SavingsGoal> get behindGoals =>
      activeGoals.where((g) => g.deadline != null && !progressOf(g).isOnTrack).toList();

  double get totalSaved => goals.where((g) => g.status != SavingsGoal.archived).fold(0.0, (s, g) => s + g.savedAmount);

  @visibleForTesting
  void seedForTest({required String userId, List<SavingsGoal> goals = const []}) {
    _userId = userId;
    this.goals = [...goals];
    notifyListeners();
  }

  Future<void> load(String userId) async {
    _userId = userId;
    if (userId.isEmpty) {
      goals = [];
      notifyListeners();
      return;
    }
    isLoading = true;
    notifyListeners();
    try {
      goals = await _service.fetchGoals(userId);
      errorMessage = null;
    } catch (_) {
      errorMessage = 'Could not load savings goals.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveGoal(SavingsGoal goal) async {
    if (!isLoggedIn) return false;
    try {
      if (goal.id == null) {
        final saved = await _service.addGoal(goal);
        if (saved == null) return false;
        goals = [...goals, saved];
      } else {
        await _service.updateGoal(goal);
        goals = [for (final g in goals) g.id == goal.id ? goal : g];
      }
      errorMessage = null;
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not save goal.';
      notifyListeners();
      return false;
    }
  }

  /// Adds (positive) or withdraws (negative) money. Returns a milestone
  /// message when the change crosses 25/50/75/100%. Reaching 100% marks the
  /// goal completed; dropping back below reopens it.
  Future<({bool ok, String? milestone})> contribute(
    SavingsGoal goal, {
    required double amount,
    String? note,
    DateTime? on,
  }) async {
    if (!isLoggedIn || goal.id == null || amount == 0) return (ok: false, milestone: null);
    if (amount < 0 && -amount > goal.savedAmount + 0.005) {
      errorMessage = "You can't withdraw more than the ${goal.savedAmount.toStringAsFixed(2)} saved.";
      notifyListeners();
      return (ok: false, milestone: null);
    }
    try {
      final before = goal.savedAmount;
      final saved = await _service.addContribution(GoalContribution(
        goalId: goal.id!,
        userId: _userId!,
        amount: amount,
        note: note,
        contributedOn: on ?? now(),
      ));
      if (saved == null) return (ok: false, milestone: null);
      var updated = goal.copyWith(contributions: [saved, ...goal.contributions]);
      final after = updated.savedAmount;
      final reached = after >= goal.targetAmount - 0.005;
      if (reached && goal.status == SavingsGoal.active) {
        await _service.setStatus(goal.id!, SavingsGoal.completed);
        updated = updated.copyWith(status: SavingsGoal.completed);
      } else if (!reached && goal.status == SavingsGoal.completed) {
        await _service.setStatus(goal.id!, SavingsGoal.active);
        updated = updated.copyWith(status: SavingsGoal.active);
      }
      goals = [for (final g in goals) g.id == goal.id ? updated : g];
      errorMessage = null;
      notifyListeners();
      final m = crossedMilestone(before, after, goal.targetAmount);
      return (ok: true, milestone: m == null ? null : milestoneMessage(m, goal.name));
    } catch (_) {
      errorMessage = 'Could not record that.';
      notifyListeners();
      return (ok: false, milestone: null);
    }
  }

  Future<bool> setStatus(SavingsGoal goal, String status) async {
    if (goal.id == null) return false;
    try {
      await _service.setStatus(goal.id!, status);
      goals = [for (final g in goals) g.id == goal.id ? g.copyWith(status: status) : g];
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not update goal.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGoal(SavingsGoal goal) async {
    if (goal.id == null) return false;
    try {
      await _service.deleteGoal(goal.id!);
      goals = goals.where((g) => g.id != goal.id).toList();
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not delete goal.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteContribution(SavingsGoal goal, GoalContribution c) async {
    if (c.id == null) return false;
    try {
      await _service.deleteContribution(c.id!);
      final updated = goal.copyWith(
          contributions: goal.contributions.where((x) => x.id != c.id).toList());
      goals = [for (final g in goals) g.id == goal.id ? updated : g];
      notifyListeners();
      return true;
    } catch (_) {
      errorMessage = 'Could not delete that entry.';
      notifyListeners();
      return false;
    }
  }
}
