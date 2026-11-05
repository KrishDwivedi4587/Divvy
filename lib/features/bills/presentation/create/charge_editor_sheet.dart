import 'package:flutter/material.dart';

import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/decimal_input.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../core/widgets/segmented_pills.dart';
import '../../domain/bill_draft.dart';
import '../../domain/engine/money.dart';
import '../../domain/engine/percent.dart';
import '../../domain/models/bill.dart';
import 'item_editor_sheet.dart' show maxEntryPaise;

sealed class ChargeEdit {
  const ChargeEdit();
}

final class ChargeSaved extends ChargeEdit {
  const ChargeSaved(this.charge);
  final DraftAdjustment charge;
}

final class ChargeDeleted extends ChargeEdit {
  const ChargeDeleted();
}

String defaultChargeLabel(AdjustmentKind kind) => switch (kind) {
  AdjustmentKind.tax => 'Tax',
  AdjustmentKind.service => 'Service charge',
  AdjustmentKind.discount => 'Discount',
  AdjustmentKind.tip => 'Tip',
  AdjustmentKind.other => 'Charge',
};

/// Adds or edits a tax, service charge, discount, tip or other charge.
Future<ChargeEdit?> showChargeEditor(
  BuildContext context, {
  required Currency currency,
  required String newId,
  AdjustmentKind kind = AdjustmentKind.tax,
  DraftAdjustment? existing,
}) {
  return showAppSheet<ChargeEdit>(
    context,
    builder: (_) => _ChargeEditor(
      currency: currency,
      newId: newId,
      kind: existing?.kind ?? kind,
      existing: existing,
    ),
  );
}

class _ChargeEditor extends StatefulWidget {
  const _ChargeEditor({
    required this.currency,
    required this.newId,
    required this.kind,
    this.existing,
  });

  final Currency currency;
  final String newId;
  final AdjustmentKind kind;
  final DraftAdjustment? existing;

  @override
  State<_ChargeEditor> createState() => _ChargeEditorState();
}

class _ChargeEditorState extends State<_ChargeEditor> {
  late AdjustmentKind _kind = widget.kind;
  late AdjustmentMode _mode = widget.existing?.mode ?? AdjustmentMode.amount;
  late final _label = TextEditingController(
    text: widget.existing?.label ?? defaultChargeLabel(widget.kind),
  );
  late final _value = TextEditingController(text: _initialValue());
  String? _error;

  String _initialValue() {
    final e = widget.existing;
    if (e == null) return '';
    if (e.mode == AdjustmentMode.percent) {
      final f = formatPercent(e.value);
      return f.substring(0, f.length - 1);
    }
    final whole = e.value ~/ 100;
    final frac = e.value % 100;
    return frac == 0 ? '$whole' : '$whole.${frac.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    super.dispose();
  }

  ({int? value, String? error}) _read() {
    final text = normalizeDecimalText(_value.text);
    if (_mode == AdjustmentMode.percent) {
      return switch (parsePercent(text)) {
        PercentOk(:final basisPoints) when basisPoints == 0 => (
          value: null,
          error: 'Enter a rate above 0',
        ),
        PercentOk(:final basisPoints) => (value: basisPoints, error: null),
        PercentError(:final reason) => (
          value: null,
          error: switch (reason) {
            PercentFailure.empty => 'Enter a percentage',
            PercentFailure.tooLarge => 'Cannot be more than 100',
            PercentFailure.tooManyDecimals => 'Use at most 2 decimal places',
            _ => 'Enter a valid percentage',
          },
        ),
      };
    }
    return switch (parseAmount(text)) {
      ParseOk(:final value) when value.isZero => (
        value: null,
        error: 'Enter an amount above 0',
      ),
      ParseOk(:final value) when value.value > maxEntryPaise => (
        value: null,
        error: 'That amount is too large',
      ),
      ParseOk(:final value) => (value: value.value, error: null),
      ParseError(:final reason) => (
        value: null,
        error: switch (reason) {
          ParseFailure.empty => 'Enter an amount',
          ParseFailure.tooManyDecimals => 'Use at most 2 decimal places',
          ParseFailure.tooLarge => 'That amount is too large',
          _ => 'Enter a valid amount',
        },
      ),
    };
  }

  void _save() {
    final read = _read();
    if (read.value == null) {
      setState(() => _error = read.error);
      return;
    }
    final label = _label.text.trim().isEmpty
        ? defaultChargeLabel(_kind)
        : _label.text.trim();
    Navigator.of(context).pop(
      ChargeSaved(
        DraftAdjustment(
          id: widget.existing?.id ?? widget.newId,
          label: label,
          kind: _kind,
          mode: _mode,
          value: read.value!,
          isNegative: _kind == AdjustmentKind.discount,
          fromReceipt: widget.existing?.fromReceipt ?? false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final percent = _mode == AdjustmentMode.percent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          editing ? 'Edit charge' : 'Add a charge',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Space.lg),
        SegmentedPills<AdjustmentKind>(
          values: const [
            AdjustmentKind.tax,
            AdjustmentKind.service,
            AdjustmentKind.discount,
            AdjustmentKind.tip,
          ],
          selected: _kind == AdjustmentKind.other ? AdjustmentKind.tax : _kind,
          label: (k) => switch (k) {
            AdjustmentKind.service => 'Service',
            _ => defaultChargeLabel(k),
          },
          onChanged: (k) => setState(() {
            final wasDefault =
                _label.text.trim() == defaultChargeLabel(_kind) ||
                _label.text.trim().isEmpty;
            _kind = k;
            if (wasDefault) _label.text = defaultChargeLabel(k);
          }),
        ),
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Name',
          controller: _label,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: Space.lg),
        SegmentedPills<AdjustmentMode>(
          values: AdjustmentMode.values,
          selected: _mode,
          label: (m) => m == AdjustmentMode.amount
              ? 'Amount (${widget.currency.symbol})'
              : 'Percent (%)',
          onChanged: (m) => setState(() {
            _mode = m;
            _error = null;
          }),
        ),
        const SizedBox(height: Space.lg),
        AmountField(
          label: percent ? 'Rate' : 'Amount',
          hint: percent ? '5' : '0.00',
          prefix: percent ? null : '${widget.currency.symbol} ',
          controller: _value,
          error: _error,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: Space.xl),
        AppButton(
          label: editing ? 'Save charge' : 'Add charge',
          onPressed: _save,
        ),
        if (editing) ...[
          const SizedBox(height: Space.xs),
          AppButton(
            label: 'Delete charge',
            kind: AppButtonKind.text,
            destructive: true,
            onPressed: () => Navigator.of(context).pop(const ChargeDeleted()),
          ),
        ],
      ],
    );
  }
}
