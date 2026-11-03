import type { ReactNode } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { Icon } from '@/ui/Icon';
import { Text } from '@/ui/Text';
import { borderWidth, colors, layout, radii, spacing } from '@/ui/theme/tokens';

export interface StepInfo {
  /** 1-based. */
  current: number;
  total: number;
  label: string;
}

export interface ScreenHeaderProps {
  title: string;
  onBack?: () => void;
  step?: StepInfo;
  trailing?: ReactNode;
}

export function ScreenHeader({ title, onBack, step, trailing }: ScreenHeaderProps) {
  return (
    <View style={styles.header}>
      <View style={styles.row}>
        {onBack ? (
          <Pressable
            onPress={onBack}
            accessibilityRole="button"
            accessibilityLabel="Go back"
            hitSlop={8}
            style={({ pressed }) => [styles.back, pressed && styles.backPressed]}
          >
            <Icon name="chevronLeft" size={18} />
          </Pressable>
        ) : null}

        <Text variant="h3" style={styles.title} numberOfLines={1} accessibilityRole="header">
          {title}
        </Text>

        {trailing}
      </View>

      {step ? <StepProgress {...step} /> : null}
    </View>
  );
}

function StepProgress({ current, total, label }: StepInfo) {
  return (
    <View
      style={styles.progress}
      accessible
      accessibilityLabel={`Step ${current} of ${total}: ${label}`}
    >
      <View style={styles.segments}>
        {Array.from({ length: total }, (_, i) => (
          <View
            key={i}
            style={[
              styles.segment,
              { backgroundColor: i < current ? colors.action.primary : colors.surface.border },
            ]}
          />
        ))}
      </View>
      <Text variant="caption" tone="muted">
        Step {current} of {total} · {label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    paddingHorizontal: layout.screenPadding,
    paddingTop: spacing.sm,
    gap: spacing.md,
  },
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, minHeight: 44 },
  title: { flex: 1 },
  back: {
    width: layout.minTouchTarget,
    height: layout.minTouchTarget,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radii.pill,
    backgroundColor: colors.surface.raised,
    borderWidth: borderWidth.thin,
    borderColor: colors.surface.border,
  },
  backPressed: { backgroundColor: colors.surface.elevated },
  progress: { gap: spacing.sm },
  segments: { flexDirection: 'row', gap: spacing.xs },
  segment: { flex: 1, height: 3, borderRadius: radii.pill },
});
