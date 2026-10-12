import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/money.dart';
import '../../models/community_models.dart';
import '../../services/community_service.dart';
import '../../viewmodels/community_viewmodel.dart';
import 'group_preview_screen.dart';
import 'person_sheet.dart';
import 'widgets/community_widgets.dart';

class DiscoverTab extends StatefulWidget {
  final VoidCallback onOpenProfileTab;
  const DiscoverTab({super.key, required this.onOpenProfileTab});

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _PeopleFilters {
  int? minBucket;
  int? maxBucket;
  Set<String> experience = {};
  Set<String> interests = {};
  String? district;
  bool verifiedOnly = false;

  int get count =>
      (minBucket != null || maxBucket != null ? 1 : 0) +
      (experience.isEmpty ? 0 : 1) +
      (interests.isEmpty ? 0 : 1) +
      (district == null ? 0 : 1) +
      (verifiedOnly ? 1 : 0);
}

class _GroupFilters {
  String? type;
  double? minAmount;
  double? maxAmount;
  String? frequency;
  bool openOnly = true;
  String? district;
  Set<String> leaderExperience = {};

  int get count =>
      (type == null ? 0 : 1) +
      (minAmount != null || maxAmount != null ? 1 : 0) +
      (frequency == null ? 0 : 1) +
      (openOnly ? 1 : 0) +
      (district == null ? 0 : 1) +
      (leaderExperience.isEmpty ? 0 : 1);
}

class _DiscoverTabState extends State<DiscoverTab> {
  static const _pageSize = 20;
  final _search = TextEditingController();
  Timer? _debounce;
  bool _groups = false;
  final _peopleFilters = _PeopleFilters();
  final _groupFilters = _GroupFilters();

  List<PersonResult> _people = [];
  List<GroupResult> _groupResults = [];
  bool _loading = false;
  bool _hasMore = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  Future<void> _runSearch({bool more = false}) async {
    final service = context.read<CommunityViewModel>().service;
    final id = ++_requestId;
    final query = _search.text.trim().isEmpty ? null : _search.text.trim();
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _people = [];
        _groupResults = [];
      }
    });
    try {
      if (_groups) {
        final f = _groupFilters;
        final page = await service.searchGroups(
          query: query,
          type: f.type,
          minAmount: f.minAmount,
          maxAmount: f.maxAmount,
          frequency: f.frequency,
          openOnly: f.openOnly,
          district: f.district,
          leaderExperience: f.leaderExperience.toList(),
          limit: _pageSize,
          offset: more ? _groupResults.length : 0,
        );
        if (id != _requestId || !mounted) return;
        setState(() {
          _groupResults = [..._groupResults, ...page];
          _hasMore = page.length == _pageSize;
        });
      } else {
        final f = _peopleFilters;
        final page = await service.searchPeople(
          query: query,
          minBucket: f.minBucket,
          maxBucket: f.maxBucket,
          experience: f.experience.toList(),
          interests: f.interests.toList(),
          district: f.district,
          verifiedOnly: f.verifiedOnly,
          limit: _pageSize,
          offset: more ? _people.length : 0,
        );
        if (id != _requestId || !mounted) return;
        setState(() {
          _people = [..._people, ...page];
          _hasMore = page.length == _pageSize;
        });
      }
    } on CommunityException catch (e) {
      if (id == _requestId && mounted) setState(() => _error = e.message);
    } finally {
      if (id == _requestId && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect(PersonResult p) async {
    final vm = context.read<CommunityViewModel>();
    if (!vm.hasProfile) {
      showResult(context, 'Set up your community profile first.');
      widget.onOpenProfileTab();
      return;
    }
    final message = await _askMessage(context, 'Connect with ${p.displayName}', 'Add a note (optional)', 150);
    if (message == null || !mounted) return;
    final error = await vm.requestConnection(p.userId, message: message.isEmpty ? null : message);
    if (!mounted) return;
    showResult(context, error, 'Request sent to ${p.displayName}.');
    if (error == null) _runSearch();
  }

  Future<void> _openGroup(GroupResult g) async {
    final vm = context.read<CommunityViewModel>();
    final joined = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(value: vm, child: GroupPreviewScreen(groupId: g.id)),
    ));
    if (joined == true && mounted) _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final filterCount = _groups ? _groupFilters.count : _peopleFilters.count;
    return RefreshIndicator(
      onRefresh: _runSearch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('People'), icon: Icon(Icons.person_search_rounded)),
              ButtonSegment(value: true, label: Text('Groups'), icon: Icon(Icons.groups_rounded)),
            ],
            selected: {_groups},
            onSelectionChanged: (s) {
              setState(() => _groups = s.first);
              _runSearch();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runSearch(),
                  decoration: InputDecoration(
                    hintText: _groups ? 'Search groups by name' : 'Search people by name',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              _runSearch();
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: filterCount > 0,
                label: Text('$filterCount'),
                child: IconButton.filledTonal(
                  tooltip: 'Filters',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () async {
                    final changed = _groups ? await _groupFilterSheet() : await _peopleFilterSheet();
                    if (changed == true) _runSearch();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_error != null)
            EmptyState(icon: Icons.cloud_off_rounded, title: 'Search failed', body: _error)
          else if (!_loading && (_groups ? _groupResults.isEmpty : _people.isEmpty))
            EmptyState(
              icon: _groups ? Icons.group_off_rounded : Icons.person_off_rounded,
              title: _groups ? 'No groups found' : 'No one found',
              body: _groups
                  ? 'Try other filters, or check back later as new groups form.'
                  : 'Only people who chose to be available for group investments appear here.',
            )
          else if (_groups)
            for (final g in _groupResults) ...[
              GroupCard(
                group: g,
                onTap: () => _openGroup(g),
                action: _groupAction(g),
              ),
              const SizedBox(height: 10),
            ]
          else
            for (final p in _people) ...[
              PersonCard(
                person: p,
                onTap: () => showPersonSheet(context, context.read<CommunityViewModel>(), p.userId,
                    onChanged: _runSearch),
                action: _personAction(p),
              ),
              const SizedBox(height: 10),
            ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: AppColors.accentCyan, strokeWidth: 2)),
            )
          else if (_hasMore)
            Center(
              child: TextButton.icon(
                onPressed: () => _runSearch(more: true),
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Load more'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _personAction(PersonResult p) {
    return switch (p.connectionStatus) {
      'accepted' => const InfoChip('Connected', icon: Icons.check_circle_rounded, color: AppColors.gain),
      'pending' => const InfoChip('Request pending', icon: Icons.schedule_rounded),
      _ => SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _connect(p),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Send connection request'),
          ),
        ),
    };
  }

  Widget _groupAction(GroupResult g) {
    if (g.isMember) return const InfoChip('You\'re a member', icon: Icons.check_circle_rounded, color: AppColors.gain);
    if (g.myRequestStatus == 'pending') return const InfoChip('Request pending', icon: Icons.schedule_rounded);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: g.isOpen ? () => _openGroup(g) : null,
        icon: const Icon(Icons.login_rounded, size: 18),
        label: Text(g.isOpen ? 'Request to join' : 'Not taking members'),
      ),
    );
  }

  Future<bool?> _peopleFilterSheet() {
    final f = _peopleFilters;
    return _filterSheet(
      title: 'Filter people',
      onReset: () {
        f
          ..minBucket = null
          ..maxBucket = null
          ..experience = {}
          ..interests = {}
          ..district = null
          ..verifiedOnly = false;
      },
      builder: (setSheet) => [
        Text('Max contribution', style: cText(13, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < kContributionBuckets.length; i++)
            FilterChip(
              label: Text(kContributionBuckets[i]),
              selected: f.minBucket != null && i >= f.minBucket! && i <= (f.maxBucket ?? f.minBucket!),
              onSelected: (_) => setSheet(() {
                // Tap one bucket, then another to make a range.
                if (f.minBucket == null || f.maxBucket != null) {
                  f.minBucket = i;
                  f.maxBucket = null;
                } else if (i == f.minBucket) {
                  f.minBucket = null;
                } else {
                  final lo = i < f.minBucket! ? i : f.minBucket!;
                  final hi = i < f.minBucket! ? f.minBucket! : i;
                  f.minBucket = lo;
                  f.maxBucket = hi;
                }
              }),
            ),
        ]),
        const SizedBox(height: 14),
        Text('Experience', style: cText(13, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in kExperienceLabels.entries)
            FilterChip(
              label: Text(e.value),
              selected: f.experience.contains(e.key),
              onSelected: (on) => setSheet(() => on ? f.experience.add(e.key) : f.experience.remove(e.key)),
            ),
        ]),
        const SizedBox(height: 14),
        Text('Interests', style: cText(13, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in kInterestLabels.entries)
            FilterChip(
              label: Text(e.value),
              selected: f.interests.contains(e.key),
              onSelected: (on) => setSheet(() => on ? f.interests.add(e.key) : f.interests.remove(e.key)),
            ),
        ]),
        const SizedBox(height: 14),
        _districtField(f.district, (d) => setSheet(() => f.district = d)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Verified phone only'),
          value: f.verifiedOnly,
          onChanged: (v) => setSheet(() => f.verifiedOnly = v),
        ),
      ],
    );
  }

  Future<bool?> _groupFilterSheet() {
    final f = _groupFilters;
    final min = TextEditingController(text: f.minAmount?.toStringAsFixed(0) ?? '');
    final max = TextEditingController(text: f.maxAmount?.toStringAsFixed(0) ?? '');
    return _filterSheet(
      title: 'Filter groups',
      onReset: () {
        f
          ..type = null
          ..minAmount = null
          ..maxAmount = null
          ..frequency = null
          ..openOnly = true
          ..district = null
          ..leaderExperience = {};
        min.clear();
        max.clear();
      },
      onApply: () {
        f.minAmount = parseAmount(min.text);
        f.maxAmount = parseAmount(max.text);
      },
      builder: (setSheet) => [
        Text('Type', style: cText(13, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [
          for (final t in const [(null, 'Any'), ('seettu', 'Seettu'), ('investment', 'Investment')])
            ChoiceChip(
              label: Text(t.$2),
              selected: f.type == t.$1,
              onSelected: (_) => setSheet(() => f.type = t.$1),
            ),
        ]),
        const SizedBox(height: 14),
        Text('Contribution amount (Rs)', style: cText(13, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(controller: min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'From')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(controller: max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'To')),
          ),
        ]),
        const SizedBox(height: 14),
        Text('Seettu frequency', style: cText(13, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [
          for (final t in const [(null, 'Any'), ('weekly', 'Weekly'), ('monthly', 'Monthly')])
            ChoiceChip(
              label: Text(t.$2),
              selected: f.frequency == t.$1,
              onSelected: (_) => setSheet(() => f.frequency = t.$1),
            ),
        ]),
        const SizedBox(height: 14),
        Text('Leader experience', style: cText(13, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in kExperienceLabels.entries)
            FilterChip(
              label: Text(e.value),
              selected: f.leaderExperience.contains(e.key),
              onSelected: (on) => setSheet(() => on ? f.leaderExperience.add(e.key) : f.leaderExperience.remove(e.key)),
            ),
        ]),
        const SizedBox(height: 14),
        _districtField(f.district, (d) => setSheet(() => f.district = d)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Open seats only'),
          value: f.openOnly,
          onChanged: (v) => setSheet(() => f.openOnly = v),
        ),
      ],
    );
  }

  Widget _districtField(String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'District'),
      items: [
        const DropdownMenuItem(value: null, child: Text('Any district')),
        for (final d in kSriLankaDistricts) DropdownMenuItem(value: d, child: Text(d)),
      ],
      onChanged: onChanged,
    );
  }

  Future<bool?> _filterSheet({
    required String title,
    required VoidCallback onReset,
    VoidCallback? onApply,
    required List<Widget> Function(StateSetter setSheet) builder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.deepNavy,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
            children: [
              Row(children: [
                Expanded(child: Text(title, style: cText(18, weight: FontWeight.w700))),
                TextButton(onPressed: () => setSheet(onReset), child: const Text('Reset')),
              ]),
              const SizedBox(height: 10),
              ...builder(setSheet),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  onApply?.call();
                  Navigator.pop(ctx, true);
                },
                child: const Text('Show results'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for an optional short message. Returns null if cancelled.
Future<String?> _askMessage(BuildContext context, String title, String label, int maxLength) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: 3,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Send')),
      ],
    ),
  );
}
