// Pure savings-goal calculations — no I/O, unit-tested.
import '../../models/savings_goal_model.dart';

const double _daysPerMonth = 30.4375;

class GoalProgress {
  final double saved;
  final double target;
  final double remaining;

  /// Whole days until the deadline (negative once passed); null without one.
  final int? daysLeft;

  /// What has to be saved per month / week from today to hit the deadline.
  final double? requiredPerMonth;
  final double? requiredPerWeek;

  /// Average net contribution per month since the goal was created.
  final double averagePerMonth;

  /// Projected share of the target reached by the deadline at the current
  /// average pace (1.0 = 100%).
  final double? projectedShareAtDeadline;
  final bool isOnTrack;
  final bool isComplete;

  const GoalProgress({
    required this.saved,
    required this.target,
    required this.remaining,
    required this.daysLeft,
    required this.requiredPerMonth,
    required this.requiredPerWeek,
    required this.averagePerMonth,
    required this.projectedShareAtDeadline,
    required this.isOnTrack,
    required this.isComplete,
  });

  double get share => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);
}

GoalProgress computeGoalProgress(SavingsGoal goal, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final saved = goal.savedAmount;
  final target = goal.targetAmount;
  final remaining = (target - saved).clamp(0.0, double.infinity);
  final complete = saved >= target - 0.005;

  final created = DateTime(goal.createdAt.year, goal.createdAt.month, goal.createdAt.day);
  // At least one month of elapsed time, so a goal funded today doesn't
  // report an inflated pace.
  final monthsElapsed = (today.difference(created).inDays / _daysPerMonth).clamp(1.0, double.infinity);
  final averagePerMonth = saved / monthsElapsed;

  int? daysLeft;
  double? perMonth;
  double? perWeek;
  double? projected;
  var onTrack = true;

  if (goal.deadline != null) {
    final deadline = DateTime(goal.deadline!.year, goal.deadline!.month, goal.deadline!.day);
    daysLeft = deadline.difference(today).inDays;
    if (complete) {
      perMonth = 0;
      perWeek = 0;
      projected = saved / target;
    } else if (daysLeft <= 0) {
      // Deadline today or passed: everything remaining is due now.
      perMonth = remaining;
      perWeek = remaining;
      projected = saved / target;
      onTrack = false;
    } else {
      final monthsLeft = daysLeft / _daysPerMonth;
      // Less than a month to go still needs the full remainder this month.
      perMonth = remaining / (monthsLeft < 1 ? 1 : monthsLeft);
      perWeek = remaining / (daysLeft / 7 < 1 ? 1 : daysLeft / 7);
      projected = (saved + averagePerMonth * monthsLeft) / target;
      onTrack = averagePerMonth >= perMonth - 0.005;
    }
  } else {
    onTrack = true; // No deadline: nothing to be behind on.
  }

  return GoalProgress(
    saved: saved,
    target: target,
    remaining: remaining,
    daysLeft: daysLeft,
    requiredPerMonth: perMonth,
    requiredPerWeek: perWeek,
    averagePerMonth: averagePerMonth,
    projectedShareAtDeadline: projected,
    isOnTrack: complete || onTrack,
    isComplete: complete,
  );
}

/// The highest milestone (25/50/75/100) crossed by moving from [before] to
/// [after] saved, or null if none was crossed.
int? crossedMilestone(double before, double after, double target) {
  if (target <= 0) return null;
  int? hit;
  for (final m in const [25, 50, 75, 100]) {
    final threshold = target * m / 100;
    if (before < threshold - 0.005 && after >= threshold - 0.005) hit = m;
  }
  return hit;
}

String milestoneMessage(int milestone, String goalName) {
  switch (milestone) {
    case 100:
      return '🎉 Goal reached — "$goalName" is fully funded!';
    case 75:
      return '75% of "$goalName" saved — the finish line is in sight.';
    case 50:
      return 'Halfway there on "$goalName"!';
    default:
      return 'Nice start — 25% of "$goalName" saved.';
  }
}

/// 31 December of [now]'s year — the "Year-end trip" template deadline.
DateTime yearEndDeadline(DateTime now) => DateTime(now.year, 12, 31);
