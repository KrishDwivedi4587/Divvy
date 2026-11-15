import 'package:flutter/material.dart';

import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/decimal_input.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../domain/engine/money.dart';
import 'item_editor_sheet.dart' show maxEntryPaise;

/// Asks for the total printed on the receipt. Returns it, or null if the sheet
/// was dismissed.
Future<Paise?> showTotalEditor(
  BuildContext context, {
  required Currency currency,
  Paise? current,
}) {
  return showAppSheet<Paise>(
    context,
    builder: (_) => _TotalEditor(currency: currency, current: current),
  );
}

class _TotalEditor extends StatefulWidget {
  const _TotalEditor({required this.currency, this.current});

  final Currency currency;
  final Paise? current;

  @override
  State<_TotalEditor> createState() => _TotalEditorState();
}

class _TotalEditorState extends State<_TotalEditor> {
  late final _controller = TextEditingController(
    text: widget.current == null ? '' : _plain(widget.current!),
  );
  String? _error;

  static String _plain(Paise p) {
    final whole = p.value ~/ 100;
    final frac = p.value % 100;
    return frac == 0 ? '$whole' : '$whole.${frac.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    switch (parseAmount(normalizeDecimalText(_controller.text))) {
      case ParseOk(:final value):
        if (value.value <= Paise.zero.value || value.value > maxEntryPaise) {
          setState(() => _error = 'Enter an amount above zero');
        } else {
          Navigator.of(context).pop(value);
        }
      case ParseError(:final reason):
        setState(
          () => _error = switch (reason) {
            ParseFailure.empty => 'Enter the total',
            ParseFailure.tooManyDecimals => 'Use at most 2 decimal places',
            ParseFailure.tooLarge => 'That amount is too large',
            _ => 'Enter a valid amount',
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Receipt total', style: t.titleLarge),
        const SizedBox(height: Space.xs),
        Text(
          'The amount printed at the bottom of the receipt. Divvy compares it '
          'with the items and charges to catch a misread price.',
          style: t.bodySmall,
        ),
        const SizedBox(height: Space.lg),
        AmountField(
          label: 'Total on the receipt',
          prefix: '${widget.currency.symbol} ',
          controller: _controller,
          error: _error,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: Space.xl),
        AppButton(label: 'Save total', onPressed: _save),
      ],
    );
  }
}
