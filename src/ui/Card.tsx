import { StyleSheet, View, type ViewProps } from 'react-native';

import { borderWidth, colors, radii, spacing, type Spacing } from '@/ui/theme/tokens';

export interface CardProps extends ViewProps {
  /** Inner padding. `none` for cards whose rows manage their own. */
  padding?: Spacing | 'none';
}

/**
 * A raised surface with a subtle border. Depth comes from the lighter surface
 * colour, not a shadow: Android shadows are black and vanish on a dark
 * background (see docs/design-tokens.md).
 */
export function Card({ padding = 'lg', style, ...rest }: CardProps) {
  return (
    <View
      {...rest}
      style={[styles.card, padding === 'none' ? null : { padding: spacing[padding] }, style]}
    />
  );
}

export function Divider() {
  return <View style={styles.divider} />;
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface.raised,
    borderRadius: radii.lg,
    borderWidth: borderWidth.thin,
    borderColor: colors.surface.border,
    overflow: 'hidden',
  },
  divider: {
    height: borderWidth.hairline,
    backgroundColor: colors.surface.border,
  },
});
