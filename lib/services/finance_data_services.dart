// Supabase access for finance settings, savings goals and debts.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../models/debt_model.dart';
import '../models/finance_settings_model.dart';
import '../models/savings_goal_model.dart';

SupabaseClient? get _client => SupabaseConfig.isConfigured ? SupabaseConfig.client : null;

class FinanceSettingsService {
  Future<FinanceSettings?> fetch(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return null;
    final row = await client.from('finance_settings').select().eq('user_id', userId).maybeSingle();
    return row == null ? null : FinanceSettings.fromJson(row);
  }

  Future<FinanceSettings?> save(String userId, {double? monthlyIncome, int? incomeDay}) async {
    final client = _client;
    if (client == null) return null;
    final row = await client
        .from('finance_settings')
        .upsert(
          {
            'user_id': userId,
            'monthly_income': monthlyIncome,
            'income_day': incomeDay,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'user_id',
        )
        .select()
        .single();
    return FinanceSettings.fromJson(row);
  }
}

class SavingsGoalService {
  Future<List<SavingsGoal>> fetchGoals(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return [];
    final rows = await client
        .from('savings_goals')
        .select('*, goal_contributions(*)')
        .eq('user_id', userId)
        .order('created_at');
    return (rows as List).map((r) => SavingsGoal.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<SavingsGoal?> addGoal(SavingsGoal goal) async {
    final client = _client;
    if (client == null) return null;
    final row = await client
        .from('savings_goals')
        .insert(goal.toJson())
        .select('*, goal_contributions(*)')
        .single();
    return SavingsGoal.fromJson(row);
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    final client = _client;
    if (client == null || goal.id == null) return;
    await client.from('savings_goals').update(goal.toJson()).eq('id', goal.id!);
  }

  Future<void> setStatus(String goalId, String status) async {
    final client = _client;
    if (client == null) return;
    await client.from('savings_goals').update({
      'status': status,
      'completed_at': status == SavingsGoal.completed ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', goalId);
  }

  Future<void> deleteGoal(String goalId) async {
    final client = _client;
    if (client == null) return;
    await client.from('savings_goals').delete().eq('id', goalId);
  }

  Future<GoalContribution?> addContribution(GoalContribution c) async {
    final client = _client;
    if (client == null) return null;
    final row = await client.from('goal_contributions').insert(c.toJson()).select().single();
    return GoalContribution.fromJson(row);
  }

  Future<void> deleteContribution(String id) async {
    final client = _client;
    if (client == null) return;
    await client.from('goal_contributions').delete().eq('id', id);
  }
}

class DebtService {
  Future<List<Debt>> fetchDebts(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) return [];
    final rows = await client
        .from('debts')
        .select('*, debt_payments(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List).map((r) => Debt.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Debt?> addDebt(Debt debt) async {
    final client = _client;
    if (client == null) return null;
    final row = await client.from('debts').insert(debt.toJson()).select('*, debt_payments(*)').single();
    return Debt.fromJson(row);
  }

  Future<void> setStatus(String debtId, String status) async {
    final client = _client;
    if (client == null) return;
    await client.from('debts').update({
      'status': status,
      'settled_at': status == Debt.settled ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', debtId);
  }

  Future<void> deleteDebt(String debtId) async {
    final client = _client;
    if (client == null) return;
    await client.from('debts').delete().eq('id', debtId);
  }

  /// The database rejects payments larger than the outstanding balance and
  /// settles the debt automatically when it reaches zero.
  Future<DebtPayment?> addPayment(DebtPayment payment) async {
    final client = _client;
    if (client == null) return null;
    final row = await client.from('debt_payments').insert(payment.toJson()).select().single();
    return DebtPayment.fromJson(row);
  }

  Future<void> deletePayment(String id) async {
    final client = _client;
    if (client == null) return;
    await client.from('debt_payments').delete().eq('id', id);
  }
}
