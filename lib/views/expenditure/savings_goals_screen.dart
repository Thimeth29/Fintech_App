import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/gradient_scaffold.dart';
import '../../core/widgets/top_nav_bar.dart';
import '../../models/savings_goal_model.dart';
import '../../services/auth_service.dart';
import '../../services/expenditure/goal_math.dart';
import '../../viewmodels/savings_goals_viewmodel.dart';
import 'widgets/expenditure_ui.dart';
import '../../core/theme/app_fonts.dart';

/// Savings goals (e.g. a year-end trip). Contributions move money into a
/// goal and are never counted as expenses.
class SavingsGoalsScreen extends StatelessWidget {
  final SavingsGoalsViewModel? viewModel;
  const SavingsGoalsScreen({super.key, this.viewModel});

  @override
  Widget build(BuildContext context) {
    final userId = AuthService().currentUser?.id;
    const body = _GoalsBody();
    return viewModel != null
        ? ChangeNotifierProvider.value(value: viewModel!, child: body)
        : ChangeNotifierProvider(create: (_) => SavingsGoalsViewModel()..load(userId ?? ''), child: body);
  }
}

const _icons = ['✈️', '🏖️', '🎓', '🏠', '🚗', '💍', '📱', '🎁', '🛟', '💰'];

class _GoalsBody extends StatelessWidget {
  const _GoalsBody();

  Future<void> _editGoal(BuildContext context, SavingsGoalsViewModel vm, [SavingsGoal? existing]) async {
    final goal = await showDialog<SavingsGoal>(
      context: context,
      builder: (_) => _GoalForm(userId: AuthService().currentUser!.id, existing: existing),
    );
    if (goal == null || !context.mounted) return;
    final ok = await vm.saveGoal(goal);
    if (context.mounted) {
      showExpSnack(context, ok ? 'Goal saved' : (vm.errorMessage ?? 'Could not save.'), isError: !ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      maxContentWidth: 860,
      appBar: const TopNavBar(
          current: AppSection.expenses, title: 'Savings Goals', showBackButton: true, isSectionRoot: false),
      bottomNavigationBar: const AppBottomNav(current: AppSection.expenses, isSectionRoot: false),
      floatingActionButton: Consumer<SavingsGoalsViewModel>(
        builder: (context, vm, _) => !vm.isLoggedIn
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.onLight,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.flag_rounded),
                label: Text('New goal', style: AppFonts.text(fontWeight: FontWeight.w700)),
                onPressed: () => _editGoal(context, vm),
              ),
      ),
      body: Consumer<SavingsGoalsViewModel>(builder: (context, vm, _) {
        if (!vm.isLoggedIn) {
          return const Padding(
              padding: EdgeInsets.all(20), child: LoggedOutCard('Log in to create savings goals.'));
        }
        if (vm.isLoading && vm.goals.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accentCyan));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            GlassCard(
              gradient: AppGradients.heroCard,
              borderColor: AppColors.glassBorderStrong,
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SAVED ACROSS GOALS', style: expText(12, weight: FontWeight.w700, color: AppColors.onGlassMuted)),
                    const SizedBox(height: 6),
                    Text(formatRs(vm.totalSaved), style: expText(28, weight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${vm.activeGoals.length} active · ${vm.completedGoals.length} completed',
                        style: expText(13, color: AppColors.onGlassMuted)),
                  ]),
                ),
                const Text('🎯', style: TextStyle(fontSize: 34)),
              ]),
            ),
            if (vm.errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(vm.errorMessage!, style: expText(13, color: AppColors.loss)),
            ],
            const SectionTitle('Active goals'),
            if (vm.activeGoals.isEmpty)
              const EmptyNote('No active goals. Tap "New goal" — try the Year-end trip template.',
                  icon: Icons.flag_outlined)
            else
              for (final g in vm.activeGoals) ...[
                _GoalCard(goal: g, progress: vm.progressOf(g), onTap: () => _openGoal(context, vm, g)),
                const SizedBox(height: 10),
              ],
            if (vm.completedGoals.isNotEmpty) ...[
              const SectionTitle('Completed'),
              for (final g in vm.completedGoals) ...[
                _GoalCard(goal: g, progress: vm.progressOf(g), onTap: () => _openGoal(context, vm, g)),
                const SizedBox(height: 10),
              ],
            ],
            if (vm.archivedGoals.isNotEmpty) ...[
              const SectionTitle('Archived'),
              for (final g in vm.archivedGoals) ...[
                _GoalCard(goal: g, progress: vm.progressOf(g), onTap: () => _openGoal(context, vm, g)),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      }),
    );
  }

  void _openGoal(BuildContext context, SavingsGoalsViewModel vm, SavingsGoal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: _GoalSheet(goalId: goal.id!, onEdit: (g) => _editGoal(context, vm, g)),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final GoalProgress progress;
  final VoidCallback onTap;
  const _GoalCard({required this.goal, required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final status = goal.status;
    return GlassCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(goal.icon ?? '🎯', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: expText(16, weight: FontWeight.w700)),
              Text('${formatRs(p.saved)} of ${formatRs(p.target)}',
                  style: expText(13, color: AppColors.onGlassMuted)),
            ]),
          ),
          Text('${(p.share * 100).round()}%', style: expText(18, weight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        RatioBar(p.share, color: p.isComplete ? AppColors.gain : AppColors.accentCyan, height: 10),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (status == SavingsGoal.completed)
            const TagChip('Completed', color: AppColors.gain, icon: Icons.check_circle_rounded)
          else if (status == SavingsGoal.archived)
            const TagChip('Archived', color: AppColors.onGlassMuted)
          else if (goal.deadline != null)
            TagChip(p.isOnTrack ? 'On track' : 'Behind',
                color: p.isOnTrack ? AppColors.gain : AppColors.warning),
          if (goal.deadline != null && status == SavingsGoal.active)
            TagChip(
              p.daysLeft! < 0 ? 'Deadline passed' : '${p.daysLeft} days left',
              color: AppColors.onGlassMuted,
              icon: Icons.event_rounded,
            ),
        ]),
        if (status == SavingsGoal.active && goal.deadline != null && !p.isComplete) ...[
          const SizedBox(height: 10),
          Text(
            'Save ${formatRs(p.requiredPerMonth!, decimals: 0)}/month '
            '(${formatRs(p.requiredPerWeek!, decimals: 0)}/week) to finish by ${shortDate(goal.deadline!)}.',
            style: expText(12.5, height: 1.4),
          ),
          if (!p.isOnTrack && p.projectedShareAtDeadline != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Behind: at this rate you'll reach ${(p.projectedShareAtDeadline! * 100).clamp(0, 999).round()}% "
                'by ${shortDate(goal.deadline!)}.',
                style: expText(12.5, color: AppColors.warning, height: 1.4),
              ),
            ),
        ],
      ]),
    );
  }
}

/// Detail sheet: add / withdraw money, history, edit, archive, delete.
class _GoalSheet extends StatefulWidget {
  final String goalId;
  final ValueChanged<SavingsGoal> onEdit;
  const _GoalSheet({required this.goalId, required this.onEdit});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _move(SavingsGoalsViewModel vm, SavingsGoal goal, {required bool withdraw}) async {
    final v = parseAmount(_amount.text);
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await vm.contribute(goal,
        amount: withdraw ? -v : v, note: _note.text.trim().isEmpty ? null : _note.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok) {
      setState(() => _error = vm.errorMessage ?? 'Could not save.');
      return;
    }
    _amount.clear();
    _note.clear();
    showExpSnack(context, r.milestone ?? (withdraw ? 'Withdrawn from goal' : 'Added to goal'));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SavingsGoalsViewModel>(builder: (context, vm, _) {
      final goal = vm.goals.where((g) => g.id == widget.goalId).firstOrNull;
      if (goal == null) return const SizedBox.shrink();
      final p = vm.progressOf(goal);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            Row(children: [
              Text(goal.icon ?? '🎯', style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(child: Text(goal.name, style: expText(20, weight: FontWeight.w700))),
              IconButton(
                tooltip: 'Edit goal',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onEdit(goal);
                },
              ),
            ]),
            const SizedBox(height: 8),
            RatioBar(p.share, color: p.isComplete ? AppColors.gain : AppColors.accentCyan, height: 10),
            const SizedBox(height: 6),
            Text('${formatRs(p.saved)} of ${formatRs(p.target)} · ${(p.share * 100).round()}%',
                style: expText(13, color: AppColors.onGlassMuted)),
            if (goal.plannedMonthlyContribution != null)
              Text('Planned: ${formatRs(goal.plannedMonthlyContribution!)}/month (reserved in safe-to-spend)',
                  style: expText(12.5, color: AppColors.onGlassMuted)),
            const SizedBox(height: 18),
            if (goal.status != SavingsGoal.archived) ...[
              AmountField(controller: _amount),
              const SizedBox(height: 10),
              TextField(
                  controller: _note, style: expText(15), decoration: const InputDecoration(labelText: 'Note (optional)')),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: expText(13, color: AppColors.loss)),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : () => _move(vm, goal, withdraw: false),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add money'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy || goal.savedAmount <= 0 ? null : () => _move(vm, goal, withdraw: true),
                    icon: const Icon(Icons.remove_rounded),
                    label: const Text('Withdraw'),
                  ),
                ),
              ]),
            ],
            const SectionTitle('History'),
            if (goal.contributions.isEmpty)
              Text('No money added yet.', style: expText(13, color: AppColors.onGlassMuted))
            else
              for (final c in goal.contributions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(c.amount >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
                      color: c.amount >= 0 ? AppColors.gain : AppColors.loss),
                  title: Text('${c.amount >= 0 ? '+' : '−'}${formatRs(c.amount.abs())}',
                      style: expText(15, weight: FontWeight.w700)),
                  subtitle: Text('${shortDate(c.contributedOn)}${c.note == null ? '' : ' · ${c.note}'}',
                      style: expText(12, color: AppColors.onGlassMuted)),
                  trailing: IconButton(
                    tooltip: 'Delete entry',
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.onGlassMuted),
                    onPressed: () async {
                      if (await confirmAction(context,
                          title: 'Delete this entry?', message: 'The goal total will be recalculated.')) {
                        await vm.deleteContribution(goal, c);
                      }
                    },
                  ),
                ),
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              OutlinedButton.icon(
                onPressed: () => vm.setStatus(
                    goal,
                    goal.status == SavingsGoal.archived
                        ? (p.isComplete ? SavingsGoal.completed : SavingsGoal.active)
                        : SavingsGoal.archived),
                icon: Icon(goal.status == SavingsGoal.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
                label: Text(goal.status == SavingsGoal.archived ? 'Restore' : 'Archive'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.loss),
                onPressed: () async {
                  if (await confirmAction(context,
                      title: 'Delete "${goal.name}"?', message: 'Its history will be deleted too.')) {
                    await vm.deleteGoal(goal);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ]),
          ],
        ),
      );
    });
  }
}

class _GoalForm extends StatefulWidget {
  final String userId;
  final SavingsGoal? existing;
  const _GoalForm({required this.userId, this.existing});

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _planned;
  DateTime? _deadline;
  late String _icon;
  String? _error;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _name = TextEditingController(text: g?.name ?? '');
    _target = TextEditingController(text: g == null ? '' : g.targetAmount.toStringAsFixed(0));
    _planned = TextEditingController(text: g?.plannedMonthlyContribution?.toStringAsFixed(0) ?? '');
    _deadline = g?.deadline;
    _icon = g?.icon ?? _icons.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _planned.dispose();
    super.dispose();
  }

  void _useYearEndTemplate() {
    setState(() {
      _name.text = 'Year-end trip';
      _icon = '✈️';
      _deadline = yearEndDeadline(DateTime.now());
    });
  }

  void _save() {
    final name = _name.text.trim();
    final target = parseAmount(_target.text);
    final plannedText = _planned.text.trim();
    final planned = plannedText.isEmpty ? null : parseAmount(plannedText);
    if (name.isEmpty) return setState(() => _error = 'Give the goal a name.');
    if (target == null || target <= 0) return setState(() => _error = 'Enter a target greater than zero.');
    if (plannedText.isNotEmpty && (planned == null || planned < 0)) {
      return setState(() => _error = 'Planned monthly amount must be a number.');
    }
    final g = widget.existing;
    Navigator.pop(
      context,
      g == null
          ? SavingsGoal(
              userId: widget.userId,
              name: name,
              targetAmount: target,
              deadline: _deadline,
              icon: _icon,
              plannedMonthlyContribution: planned,
            )
          : g.copyWith(
              name: name,
              targetAmount: target,
              deadline: _deadline,
              clearDeadline: _deadline == null,
              icon: _icon,
              plannedMonthlyContribution: planned,
              clearPlanned: planned == null,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    return AlertDialog(
      title: Text(widget.existing == null ? 'New savings goal' : 'Edit goal'),
      content: DialogBody(children: [
        if (widget.existing == null)
          Align(
            alignment: Alignment.centerLeft,
            child: ChoicePill(
                label: '✈️  Year-end trip template', selected: false, onTap: _useYearEndTemplate),
          ),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final i in _icons)
            GestureDetector(
              onTap: () => setState(() => _icon = i),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _icon == i ? AppColors.innerFillSelected : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _icon == i ? Colors.white : Colors.transparent),
                ),
                child: Text(i, style: const TextStyle(fontSize: 20)),
              ),
            ),
        ]),
        TextField(controller: _name, style: expText(15), decoration: const InputDecoration(labelText: 'Goal name')),
        AmountField(controller: _target, label: 'Target amount (LKR)'),
        DateField(
          label: 'Deadline (optional)',
          value: _deadline,
          onTap: () async {
            final d = await pickDate(context,
                initial: _deadline ?? yearEndDeadline(today), first: today, last: DateTime(today.year + 30));
            if (d != null) setState(() => _deadline = d);
          },
          onClear: () => setState(() => _deadline = null),
        ),
        AmountField(controller: _planned, label: 'Planned per month (optional)'),
        if (_error != null) Text(_error!, style: expText(13, color: AppColors.loss)),
      ]),
      actions: dialogActions(context, saveLabel: 'Save goal', onSave: _save),
    );
  }
}
