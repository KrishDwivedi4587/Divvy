import 'package:flutter/material.dart';

import '../../../../core/constants/spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/decimal_input.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../domain/bill_draft.dart';
import '../../domain/engine/money.dart';
import '../../domain/models/bill.dart';

/// What the item editor hands back: a saved item, or a request to delete it.
sealed class ItemEdit {
  const ItemEdit();
}

final class ItemSaved extends ItemEdit {
  const ItemSaved(this.item);
  final DraftItem item;
}

final class ItemDeleted extends ItemEdit {
  const ItemDeleted();
}

/// Largest single price accepted: 10,00,000. Anything beyond is almost
/// certainly a typo, and it keeps every product the engine computes exact.
const int maxEntryPaise = 100000000;

/// Adds or edits one item. [existing] is null when adding.
Future<ItemEdit?> showItemEditor(
  BuildContext context, {
  required Currency currency,
  required String newId,
  DraftItem? existing,
}) {
  return showAppSheet<ItemEdit>(
    context,
    builder: (_) =>
        _ItemEditor(currency: currency, newId: newId, existing: existing),
  );
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({
    required this.currency,
    required this.newId,
    this.existing,
  });

  final Currency currency;
  final String newId;
  final DraftItem? existing;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _qty = TextEditingController(
    text: '${widget.existing?.quantity ?? 1}',
  );
  late final _total = TextEditingController(
    text: widget.existing == null ? '' : _plain(widget.existing!.lineTotal),
  );
  String? _nameError;
  String? _qtyError;
  String? _totalError;

  static String _plain(Paise p) {
    final v = p.value;
    final whole = v ~/ 100;
    final frac = v % 100;
    return frac == 0 ? '$whole' : '$whole.${frac.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _total.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final qty = int.tryParse(_qty.text.trim());
    final parsed = parseAmount(normalizeDecimalText(_total.text));

    String? nameError;
    String? qtyError;
    String? totalError;
    if (name.isEmpty) nameError = 'Enter the item name';
    if (qty == null || qty < 1 || qty > 99) qtyError = '1 to 99';
    Paise? total;
    switch (parsed) {
      case ParseOk(:final value):
        if (value.value > maxEntryPaise) {
          totalError = 'That amount is too large';
        } else {
          total = value;
        }
      case ParseError(:final reason):
        totalError = switch (reason) {
          ParseFailure.empty => 'Enter the price',
          ParseFailure.tooManyDecimals => 'Use at most 2 decimal places',
          ParseFailure.tooLarge => 'That amount is too large',
          _ => 'Enter a valid amount',
        };
    }

    if (nameError != null || qtyError != null || totalError != null) {
      setState(() {
        _nameError = nameError;
        _qtyError = qtyError;
        _totalError = totalError;
      });
      return;
    }

    final existing = widget.existing;
    final quantity = qty!;
    final line = total!;
    Navigator.of(context).pop(
      ItemSaved(
        DraftItem(
          id: existing?.id ?? widget.newId,
          name: name,
          quantity: quantity,
          unitPrice: Paise(quantity > 1 ? line.value ~/ quantity : line.value),
          lineTotal: line,
          // Once a person has touched an item it is no longer "unchecked".
          source: existing == null ? ItemSource.manual : existing.source,
          ocrConfidence: existing == null ? null : 1,
          rawText: existing?.rawText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          editing ? 'Edit item' : 'Add item',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (editing && widget.existing!.rawText != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            'Read as: ${widget.existing!.rawText}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: Space.lg),
        AppTextField(
          label: 'Item',
          hint: 'e.g. Paneer Tikka',
          controller: _name,
          error: _nameError,
          autofocus: !editing,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _nameError = null),
        ),
        const SizedBox(height: Space.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: AppTextField(
                label: 'Qty',
                controller: _qty,
                error: _qtyError,
                keyboardType: TextInputType.number,
                maxLength: 2,
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() => _qtyError = null),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: AmountField(
                label: 'Total price',
                prefix: '${widget.currency.symbol} ',
                controller: _total,
                error: _totalError,
                onChanged: (_) => setState(() => _totalError = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        Text(
          'The price for the whole line, not each one.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Space.xl),
        AppButton(label: editing ? 'Save item' : 'Add item', onPressed: _save),
        if (editing) ...[
          const SizedBox(height: Space.xs),
          AppButton(
            label: 'Delete item',
            kind: AppButtonKind.text,
            destructive: true,
            onPressed: () => Navigator.of(context).pop(const ItemDeleted()),
          ),
        ],
      ],
    );
  }
}
