import { StyleSheet, Text, View } from 'react-native';

/**
 * Phase 0 / Unit A placeholder.
 * Proves the project boots. Styles are intentionally inline and temporary —
 * Unit D introduces src/ui/theme/tokens.ts and this screen is re-pointed at it.
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
    backgroundColor: '#0B1220',
  },
  title: {
    fontSize: 40,
    fontWeight: '700',
    color: '#FFFFFF',
    letterSpacing: -0.5,
  },
  tagline: {
    marginTop: 8,
    fontSize: 16,
    color: '#8A94A6',
  },
});
