import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';

import { Icon, type IconName } from '@/ui/Icon';
import { Text, type TextTone } from '@/ui/Text';
import {
  borderWidth,
  colors,
  fontWeight,
  layout,
  opacity,
  radii,
  spacing,
} from '@/ui/theme/tokens';

export type ButtonVariant = 'primary' | 'secondary' | 'ghost';

export interface ButtonProps {
  label: string;
  onPress: () => void;
  variant?: ButtonVariant;
  icon?: IconName;
  /** Shows a spinner and blocks presses. */
  loading?: boolean;
  disabled?: boolean;
  /** Shorter button for inline use. Still meets the 44pt touch target. */
  compact?: boolean;
  accessibilityHint?: string;
  testID?: string;
}

const TONE: Record<ButtonVariant, TextTone> = {
  primary: 'onAction',
  secondary: 'primary',
  ghost: 'secondary',
};

const ICON_COLOR: Record<ButtonVariant, string> = {
  primary: colors.action.onPrimary,
  secondary: colors.text.primary,
  ghost: colors.text.secondary,
};

export function Button({
  label,
  onPress,
  variant = 'primary',
  icon,
  loading = false,
  disabled = false,
  compact = false,
  accessibilityHint,
  testID,
}: ButtonProps) {
  const blocked = disabled || loading;

  return (
    <Pressable
      onPress={onPress}
      disabled={blocked}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityHint={accessibilityHint}
      accessibilityState={{ disabled: blocked, busy: loading }}
      testID={testID}
      style={({ pressed }) => [
        styles.base,
        compact ? styles.compact : styles.regular,
        variant === 'primary' && {
          backgroundColor: pressed ? colors.action.primaryPressed : colors.action.primary,
        },
        variant === 'secondary' && {
          backgroundColor: pressed ? colors.surface.overlay : colors.surface.elevated,
          borderWidth: borderWidth.thin,
          borderColor: colors.surface.borderStrong,
        },
        variant === 'ghost' && {
          backgroundColor: pressed ? colors.surface.raised : 'transparent',
        },
        blocked && { opacity: opacity.disabled },
      ]}
    >
      <View style={styles.content}>
        {loading ? (
          <ActivityIndicator size="small" color={ICON_COLOR[variant]} />
        ) : icon ? (
          <Icon name={icon} size={18} color={ICON_COLOR[variant]} />
        ) : null}
        <Text
          variant={compact ? 'label' : 'body'}
          tone={TONE[variant]}
          numberOfLines={1}
          style={styles.label}
        >
          {label}
        </Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  base: {
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radii.md,
    paddingHorizontal: spacing.lg,
  },
  regular: { minHeight: 54 },
  compact: { minHeight: layout.minTouchTarget },
  label: { fontWeight: fontWeight.bold },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
  },
});
