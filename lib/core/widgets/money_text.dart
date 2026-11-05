import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../features/bills/domain/engine/money.dart';
import '../utils/currency.dart';

/// Money as text, in tabular figures so digits keep a fixed width and columns
/// of amounts line up.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount,
    this.currency, {
    this.style,
    this.color,
    this.showPlus = false,
    this.textAlign,
    super.key,
  });

  final Paise amount;
  final Currency currency;
  final TextStyle? style;
  final Color? color;

  /// Prefixes positive amounts with "+", for balances.
  final bool showPlus;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge!;
    final text = formatMoney(amount, currency);
    return Text(
      showPlus && amount > Paise.zero ? '+$text' : text,
      textAlign: textAlign,
      style: base.copyWith(color: color ?? base.color).tabular,
    );
  }
}
