import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/decimal_input.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/avatar.dart';
import '../../application/bill_draft_notifier.dart';
import '../../domain/engine/money.dart';
import 'item_editor_sheet.dart' show maxEntryPaise;

String _plain(Paise p) {
  final whole = p.value ~/ 100;
  final frac = p.value % 100;
  if (p.value == 0) return '';
  return frac == 0 ? '$whole' : '$whole.${frac.toString().padLeft(2, '0')}';
}

/// Split by explicit amounts: give each person a number, and the items total
/// has to be accounted for exactly. Taxes and charges are then shared out in
/// proportion to those amounts.
class CustomAmountsSection extends ConsumerStatefulWidget {
  const CustomAmountsSection({super.key});

  @override
  ConsumerState<CustomAmountsSection> createState() =>
      _CustomAmountsSectionState();
}

class _CustomAmountsSectionState extends ConsumerState<CustomAmountsSection> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _errors = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String id, Paise current) {
    return _controllers.putIfAbsent(
      id,
      () => TextEditingController(text: _plain(current)),
    );
  }

  void _changed(String id, String text) {
    final parsed = parseAmount(normalizeDecimalText(text));
    final notifier = ref.read(billDraftProvider.notifier);
    switch (parsed) {
      case ParseOk(:final value) when value.value <= maxEntryPaise:
        _errors[id] = null;
        notifier.setCustomAmount(id, value);
      case ParseError(:final reason) when reason == ParseFailure.empty:
        _errors[id] = null;
        notifier.setCustomAmount(id, Paise.zero);
      default:
        _errors[id] = 'Enter a valid amount';
    }
    setState(() {});
  }

  void _splitEvenly() {
    ref.read(billDraftProvider.notifier).distributeCustomEvenly();
    final draft = ref.read(billDraftProvider);
    setState(() {
      for (final p in draft.participants) {
        _controllerFor(p.id, Paise.zero).text = _plain(
          draft.customAmounts[p.id] ?? Paise.zero,
        );
        _errors[p.id] = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final draft = ref.watch(billDraftProvider);
    final Currency currency = draft.currency;
    final left = draft.itemsSubtotal - draft.customTotal;

    final (message, ok) = left.isZero
        ? ('Everything is accounted for', true)
        : left > Paise.zero
        ? ('Left to assign: ${formatMoney(left, currency)}', false)
        : ('Over by ${formatMoney(-left, currency)}', false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter what each person had, before taxes and charges. The amounts '
          'must add up to ${formatMoney(draft.itemsSubtotal, currency)}.',
          style: t.bodyMedium?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: Space.lg),
        AppCard(
          child: Column(
            children: [
              for (final p in draft.participants) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: PersonAvatar(
                        name: p.name,
                        tone: p.colorIndex,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: AmountField(
                        label: p.name,
                        prefix: '${currency.symbol} ',
                        controller: _controllerFor(
                          p.id,
                          draft.customAmounts[p.id] ?? Paise.zero,
                        ),
                        error: _errors[p.id],
                        onChanged: (v) => _changed(p.id, v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
              ],
              Row(
                children: [
                  Icon(
                    ok
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    size: 18,
                    color: ok ? c.textSecondary : c.warning,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      message,
                      style: t.labelMedium?.copyWith(
                        color: ok ? c.textPrimary : c.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        AppButton(
          label: 'Split evenly',
          icon: Icons.balance_rounded,
          kind: AppButtonKind.secondary,
          onPressed: _splitEvenly,
        ),
      ],
    );
  }
}
