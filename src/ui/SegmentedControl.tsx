import { Pressable, StyleSheet, View } from 'react-native';

import { Text } from '@/ui/Text';
import { borderWidth, colors, radii, spacing } from '@/ui/theme/tokens';

export interface SegmentOption<T extends string> {
  value: T;
  label: string;
  /** Spoken label for screen readers, e.g. "Percent" for "%". */
  accessibilityLabel: string;
}

export interface SegmentedControlProps<T extends string> {
  options: readonly SegmentOption<T>[];
  value: T;
  onChange: (value: T) => void;
}

/** A compact two-or-three-way toggle, used for the "%" / "₹" unit switch. */
export function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
}: SegmentedControlProps<T>) {
  return (
    <View style={styles.track} accessibilityRole="radiogroup">
      {options.map((option) => {
        const selected = option.value === value;
        return (
          <Pressable
            key={option.value}
            onPress={() => onChange(option.value)}
            accessibilityRole="radio"
            accessibilityLabel={option.accessibilityLabel}
            accessibilityState={{ selected, checked: selected }}
            hitSlop={{ top: 6, bottom: 6 }}
            style={[styles.segment, selected && styles.selected]}
          >
            <Text variant="label" tone={selected ? 'onAction' : 'secondary'}>
              {option.label}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  track: {
    flexDirection: 'row',
    padding: 3,
    gap: 2,
    borderRadius: radii.sm + 2,
    backgroundColor: colors.surface.background,
    borderWidth: borderWidth.thin,
    borderColor: colors.surface.border,
  },
  segment: {
    minWidth: 38,
    height: 34,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: spacing.sm,
    borderRadius: radii.sm,
  },
  selected: { backgroundColor: colors.action.primary },
});
