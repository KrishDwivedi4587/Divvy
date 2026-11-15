import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router/navigation.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/states.dart';
import '../../../shared/providers/data_providers.dart';
import '../../bills/domain/bill_repository.dart';
import '../../bills/domain/models/bill_record.dart';
import '../../bills/presentation/start_bill.dart';
import 'bill_filter_sheet.dart';
import 'bill_tile.dart';
import 'status_filter_chips.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _text = '';
  BillStatusFilter _status = BillStatusFilter.all;
  BillSort _sort = BillSort.newest;
  BillPeriod _period = BillPeriod.anyTime;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {}); // refresh the clear button straight away
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _text = value.trim());
    });
  }

  Future<void> _openFilters() async {
    final view = await showBillFilters(context, sort: _sort, period: _period);
    if (view == null || !mounted) return;
    setState(() {
      _sort = view.sort;
      _period = view.period;
    });
  }

  void _clearSearch() {
    _search.clear();
    _debounce?.cancel();
    setState(() => _text = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final query = BillQuery(
      text: _text,
      status: _status,
      sort: _sort,
      period: _period,
    );
    final bills = ref.watch(billListProvider(query));
    final anyBills = ref.watch(billCountProvider).value ?? 0;
    final filtering = query.isFiltering;
    final reordered = _sort != BillSort.newest;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.lg,
                    Space.gutter,
                    Space.md,
                  ),
                  child: Text('Past bills', style: t.headlineLarge),
                ),
                if (anyBills > 0 || filtering) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.gutter,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _search,
                            hint: 'Search bills or people',
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            suffix: _search.text.isEmpty
                                ? Icon(
                                    Icons.search_rounded,
                                    color: c.textTertiary,
                                  )
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                    ),
                                    onPressed: _clearSearch,
                                  ),
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        FilterButton(
                          active: reordered || _period != BillPeriod.anyTime,
                          onTap: _openFilters,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  StatusFilterChips(
                    selected: _status,
                    onSelected: (s) => setState(() => _status = s),
                  ),
                  const SizedBox(height: Space.md),
                ],
                Expanded(
                  child: bills.when(
                    loading: () => const LoadingState(),
                    error: (e, _) => ErrorState(
                      message: "Your bills couldn't be loaded.",
                      onRetry: () => ref.invalidate(billListProvider(query)),
                    ),
                    data: (list) => _body(context, list, filtering, query),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<BillSummary> list,
    bool filtering,
    BillQuery query,
  ) {
    if (list.isEmpty) {
      return filtering
          ? EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No bills match',
              message: 'Try a different search or filter.',
              actionLabel: 'Clear filters',
              onAction: () {
                _clearSearch();
                setState(() {
                  _status = BillStatusFilter.all;
                  _period = BillPeriod.anyTime;
                });
              },
            )
          : EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No bills yet',
              message:
                  'Split your first bill and it will be saved here with '
                  'its receipt.',
              actionLabel: 'New bill',
              onAction: () => startNewBill(context, ref),
            );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.xxl,
      ),
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Hairline(),
                BillTile(
                  bill: list[i],
                  onTap: () => context.open(AppRoutes.bill(list[i].id)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
