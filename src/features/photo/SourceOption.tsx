import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';

import { Icon, type IconName } from '@/ui/Icon';
import { Text } from '@/ui/Text';
import { borderWidth, colors, opacity, radii, spacing } from '@/ui/theme/tokens';

export interface SourceOptionProps {
  icon: IconName;
  title: string;
  description: string;
  onPress: () => void;
  loading?: boolean;
  disabled?: boolean;
  testID?: string;
}

/** A large, full-width choice. The whole card is the tap target. */
export function SourceOption({
  icon,
  title,
  description,
  onPress,
  loading = false,
  disabled = false,
  testID,
}: SourceOptionProps) {
  const blocked = disabled || loading;

  return (
    <Pressable
      onPress={onPress}
      disabled={blocked}
      accessibilityRole="button"
      accessibilityLabel={title}
      accessibilityHint={description}
      accessibilityState={{ disabled: blocked, busy: loading }}
      testID={testID}
      style={({ pressed }) => [
        styles.card,
        pressed && styles.pressed,
        blocked && !loading && { opacity: opacity.disabled },
      ]}
    >
      <View style={styles.iconBadge}>
        <Icon name={icon} size={24} />
      </View>

      <View style={styles.copy}>
        <Text variant="h3">{title}</Text>
        <Text variant="bodySmall" tone="secondary">
          {description}
        </Text>
      </View>

      {loading ? (
        <ActivityIndicator color={colors.text.secondary} />
      ) : (
        <Icon name="chevronRight" size={16} color={colors.text.muted} />
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.lg,
    minHeight: 88,
    padding: spacing.lg,
    borderRadius: radii.lg,
    backgroundColor: colors.surface.raised,
    borderWidth: borderWidth.thin,
    borderColor: colors.surface.border,
  },
  pressed: { backgroundColor: colors.surface.elevated },
  iconBadge: {
    width: 52,
    height: 52,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radii.md,
    backgroundColor: colors.surface.elevated,
    borderWidth: borderWidth.thin,
    borderColor: colors.surface.borderStrong,
  },
  copy: { flex: 1, gap: 2 },
});
