import { StyleSheet, View } from 'react-native';

import { Text } from '@/ui/Text';
import { colors, spacing } from '@/ui/theme/tokens';

/**
 * Two overlapping discs — a bill shared between people — beside the wordmark.
 * Drawn from plain views so it needs no image asset and scales cleanly.
 */
export function BrandMark({ size = 28 }: { size?: number }) {
  const disc = size;
  const overlap = Math.round(size * 0.38);

  return (
    <View style={styles.row} accessibilityRole="header" accessibilityLabel="Divvy">
      <View style={[styles.discs, { height: disc, width: disc * 2 - overlap }]}>
        <View
          style={[
            styles.disc,
            {
              width: disc,
              height: disc,
              borderRadius: disc / 2,
              backgroundColor: colors.text.primary,
            },
          ]}
        />
        <View
          style={[
            styles.disc,
            {
              left: disc - overlap,
              width: disc,
              height: disc,
              borderRadius: disc / 2,
              backgroundColor: colors.action.primary,
              // A ring in the page colour separates the two discs where they overlap.
              borderWidth: 2,
              borderColor: colors.surface.background,
            },
          ]}
        />
      </View>
      <Text variant="h3">Divvy</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  discs: { position: 'relative' },
  disc: { position: 'absolute', top: 0, left: 0 },
});
