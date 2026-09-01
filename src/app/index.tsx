import { StyleSheet, Text, View } from 'react-native';

import { colors, layout, spacing, typography } from '@/ui/theme/tokens';

/**
 * Phase 0 placeholder. Exists to prove the app boots and that the token layer
 * resolves through the `@/` alias. Replaced by the real Home screen in Phase 3.
 */
export default function Index() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>Divvy</Text>
      <Text style={styles.tagline}>Split the bill. Fairly.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: layout.screenPadding,
    backgroundColor: colors.surface.background,
  },
  title: {
    ...typography.h1,
    color: colors.text.primary,
  },
  tagline: {
    ...typography.body,
    marginTop: spacing.sm,
    color: colors.text.secondary,
  },
});
