import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../constants/spacing.dart';
import '../utils/decimal_input.dart';

/// Keeps a decimal field well-formed as the user types: digits and one point,
/// at most [maxDecimals] places. A pasted "1,234" becomes "1234" rather than
/// being guessed at (a comma read as a decimal point would be a thousand-fold
/// error in a money field).
class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.maxDecimals = 2, this.maxIntegerDigits = 8});

  final int maxDecimals;
  final int maxIntegerDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = sanitizeDecimalInput(
      newValue.text,
      maxDecimals: maxDecimals,
      maxIntegerDigits: maxIntegerDigits,
    );
    if (cleaned == newValue.text) return newValue;
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

/// A labelled text field. The label sits above the field rather than floating
/// inside it, which keeps a form of several fields calm and aligned.
class AppTextField extends StatelessWidget {
  const AppTextField({
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.error,
    this.helper,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.autocorrect = true,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? error;
  final String? helper;
  final String? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final bool autocorrect;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: t.labelMedium?.copyWith(color: c.textSecondary)),
          const SizedBox(height: Space.sm),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          autocorrect: autocorrect,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          textAlign: textAlign,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: t.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
            helperText: helper,
            counterText: '',
            prefixText: prefix,
            prefixStyle: t.bodyLarge?.copyWith(color: c.textSecondary),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// A money or percentage field with the decimal keypad.
class AmountField extends StatelessWidget {
  const AmountField({
    this.label,
    this.hint = '0.00',
    this.controller,
    this.focusNode,
    this.error,
    this.prefix,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.maxDecimals = 2,
    super.key,
  });

  final String? label;
  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? error;
  final String? prefix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final int maxDecimals;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      hint: hint,
      controller: controller,
      focusNode: focusNode,
      error: error,
      prefix: prefix,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [DecimalInputFormatter(maxDecimals: maxDecimals)],
      autocorrect: false,
    );
  }
}
