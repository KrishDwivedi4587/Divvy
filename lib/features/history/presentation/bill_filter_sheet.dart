import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/dialogs.dart';
import '../../bills/domain/bill_repository.dart';

String sortLabel(BillSort s) => switch (s) {
  BillSort.newest => 'Newest first',
  BillSort.oldest => 'Oldest first',
  BillSort.highest => 'Highest amount',
};

String periodLabel(BillPeriod p) => switch (p) {
  BillPeriod.anyTime => 'Any time',
  BillPeriod.last30Days => 'Last 30 days',
  BillPeriod.last90Days => 'Last 90 days',
  BillPeriod.thisYear => 'This year',
};

/// The sort order and date range chosen in [showBillFilters].
typedef BillView = ({BillSort sort, BillPeriod period});

/// Opens the sort and date-range sheet. Returns the choice, or null if it was
/// dismissed without pressing a button.
Future<BillView?> showBillFilters(
  BuildContext context, {
  required BillSort sort,
  required BillPeriod period,
}) {
  return showAppSheet<BillView>(
    context,
    builder: (_) => _BillFilters(sort: sort, period: period),
  );
}

class _BillFilters extends StatefulWidget {
  const _BillFilters({required this.sort, required this.period});

  final BillSort sort;
  final BillPeriod period;

  @override
  State<_BillFilters> createState() => _BillFiltersState();
}

class _BillFiltersState extends State<_BillFilters> {
  late BillSort _sort = widget.sort;
  late BillPeriod _period = widget.period;

  bool get _isDefault =>
      _sort == BillSort.newest && _period == BillPeriod.anyTime;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text('Sort and filter', style: t.titleLarge)),
            if (!_isDefault)
              TextButton(
                onPressed: () => setState(() {
                  _sort = BillSort.newest;
                  _period = BillPeriod.anyTime;
                }),
                child: const Text('Reset'),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        _Group<BillSort>(
          title: 'Sort by',
          values: BillSort.values,
          selected: _sort,
          label: sortLabel,
          onSelected: (v) => setState(() => _sort = v),
        ),
        const SizedBox(height: Space.lg),
        _Group<BillPeriod>(
          title: 'Date',
          values: BillPeriod.values,
          selected: _period,
          label: periodLabel,
          onSelected: (v) => setState(() => _period = v),
        ),
        const SizedBox(height: Space.xl),
        AppButton(
          label: 'Show bills',
          onPressed: () =>
              Navigator.of(context)
                  .pop<BillView>((sort: _sort, period: _period)),
        ),
      ],
    );
  }
}

class _Group<T> extends StatelessWidget {
  const _Group({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: t.labelSmall?.copyWith(color: c.textSecondary),
        ),
        for (final v in values)
          Semantics(
            button: true,
            selected: v == selected,
            label: label(v),
            excludeSemantics: true,
            child: InkWell(
              onTap: () => onSelected(v),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: Space.minTap),
                child: Row(
                  children: [
                    Expanded(child: Text(label(v), style: t.bodyLarge)),
                    if (v == selected)
                      const Icon(Icons.check_rounded, size: 22),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The button beside the search field that opens the sort and date sheet. A
/// dot shows when it is changing what the list looks like.
class FilterButton extends StatelessWidget {
  const FilterButton({required this.active, required this.onTap, super.key});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: active ? 'Sort and filter, active' : 'Sort and filter',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Corners.control,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Corners.control,
            border: Border.all(color: active ? c.ink : c.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.tune_rounded, size: 22),
              if (active)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
