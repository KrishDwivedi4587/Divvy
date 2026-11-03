import { useState, type ReactNode, type Ref } from 'react';
import { StyleSheet, TextInput, View, type TextInputProps } from 'react-native';

import { Icon } from '@/ui/Icon';
import { Text } from '@/ui/Text';
import { borderWidth, colors, layout, radii, spacing, typography } from '@/ui/theme/tokens';

export interface TextFieldProps extends Omit<
  TextInputProps,
  'style' | 'value' | 'onChangeText' | 'placeholderTextColor'
> {
  label: string;
  value: string;
  onChangeText: (text: string) => void;
  /** Shown beneath the field in the error colour, with an icon. */
  error?: string;
  /** Shown beneath the field when there is no error. */
  helper?: string;
  /** Leading text inside the field, e.g. a currency symbol. */
  prefix?: string;
  /** Trailing content inside the field, e.g. a unit toggle. */
  accessory?: ReactNode;
  inputRef?: Ref<TextInput>;
}

export function TextField({
  label,
  value,
  onChangeText,
  error,
  helper,
  prefix,
  accessory,
  inputRef,
  onFocus,
  onBlur,
  ...rest
}: TextFieldProps) {
  const [focused, setFocused] = useState(false);
  const highlighted = focused || Boolean(error);

  return (
    <View style={styles.wrapper}>
      <Text variant="label" tone="secondary">
        {label}
      </Text>

      <View
        style={[
          styles.field,
          {
            borderColor: error
              ? colors.status.error
              : focused
                ? colors.action.primary
                : colors.surface.borderStrong,
            // A 2px border while focused or invalid, 1px otherwise. The padding
            // compensates by the same amount so the field never changes size.
            borderWidth: highlighted ? borderWidth.thick : borderWidth.thin,
            paddingHorizontal: spacing.md + (highlighted ? 0 : 1),
          },
        ]}
      >
        {prefix ? (
          <Text variant="body" tone="muted" tabular>
            {prefix}
          </Text>
        ) : null}

        <TextInput
          {...rest}
          ref={inputRef}
          value={value}
          onChangeText={onChangeText}
          onFocus={(e) => {
            setFocused(true);
            onFocus?.(e);
          }}
          onBlur={(e) => {
            setFocused(false);
            onBlur?.(e);
          }}
          placeholderTextColor={colors.text.muted}
          selectionColor={colors.action.primary}
          accessibilityLabel={rest.accessibilityLabel ?? label}
          style={styles.input}
        />

        {accessory}
      </View>

      {error ? (
        <View style={styles.message} accessibilityLiveRegion="polite">
          <Icon name="warning" size={14} color={colors.status.error} />
          <Text variant="caption" tone="error" style={styles.messageText}>
            {error}
          </Text>
        </View>
      ) : helper ? (
        <Text variant="caption" tone="muted">
          {helper}
        </Text>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: { gap: spacing.sm },
  field: {
    minHeight: 54,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    borderRadius: radii.md,
    backgroundColor: colors.surface.raised,
  },
  input: {
    flex: 1,
    minHeight: layout.minTouchTarget,
    color: colors.text.primary,
    fontSize: typography.body.fontSize,
    paddingVertical: spacing.sm,
    // Web only: the field already draws its own focus border, so suppress the
    // browser default outline that would otherwise render inside it.
    outlineWidth: 0,
  },
  message: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs },
  messageText: { flex: 1 },
});
