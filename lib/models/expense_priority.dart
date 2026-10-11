/// Expense categories offered in the app.
const List<String> kExpenseCategories = [
  'Food', 'Transport', 'Housing', 'Utilities', 'Entertainment', 'Other',
];

/// Needs-vs-wants priority of an expense, stored as text in the
/// `expenses.priority` / `recurring_expenses.priority` columns.
class ExpensePriority {
  static const String essential = 'essential';
  static const String important = 'important';
  static const String flexible = 'flexible';

  static const List<String> values = [essential, important, flexible];

  /// Default for a category (matches the migration's backfill).
  static String defaultFor(String category) {
    switch (category) {
      case 'Housing':
      case 'Utilities':
      case 'Transport':
        return essential;
      case 'Food':
        return important;
      default:
        return flexible;
    }
  }

  /// A stored value, or the category default when missing/unknown (e.g. a
  /// row read before the migration added the column).
  static String normalise(String? value, String category) =>
      values.contains(value) ? value! : defaultFor(category);

  static String label(String priority) {
    switch (priority) {
      case essential:
        return 'Essential';
      case important:
        return 'Important';
      default:
        return 'Flexible';
    }
  }

  /// The 50/30/20 guideline share this priority maps onto
  /// (Needs / Wants / Savings is approximated as Essential / Important+Flexible).
  static String guidelineLabel(String priority) {
    switch (priority) {
      case essential:
        return 'Needs';
      case important:
        return 'Important';
      default:
        return 'Wants';
    }
  }
}
