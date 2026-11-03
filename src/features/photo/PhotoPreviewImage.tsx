import { Image } from 'expo-image';
import { useState } from 'react';
import { ActivityIndicator, StyleSheet, View, useWindowDimensions } from 'react-native';

import type { BillPhoto } from '@/domain/photo';
import { Icon } from '@/ui/Icon';
import { Text } from '@/ui/Text';
import { borderWidth, colors, radii, spacing } from '@/ui/theme/tokens';

type LoadState = 'loading' | 'ready' | 'failed';

/**
 * The bill photo at a readable size.
 *
 * The frame has a fixed height and the image is letterboxed inside it
 * (`contain`), so a tall receipt, a wide one and a square crop all display whole
 * without distortion or cropping.
 *
 * Callers should pass `key={photo.uri}`: the load state belongs to one image,
 * and remounting on a new photo resets it to "loading".
 */
export function PhotoPreviewImage({ photo }: { photo: BillPhoto }) {
  const { height } = useWindowDimensions();
  const [state, setState] = useState<LoadState>('loading');

  const frameHeight = Math.max(280, Math.min(height * 0.5, 520));

  return (
    <View style={[styles.frame, { height: frameHeight }]}>
      <Image
        source={{ uri: photo.uri }}
        style={styles.image}
        contentFit="contain"
        onLoad={() => setState('ready')}
        onError={() => setState('failed')}
        accessibilityLabel="Photo of your bill"
        accessibilityIgnoresInvertColors
      />

      {state === 'loading' ? (
        <View style={styles.overlay}>
          <ActivityIndicator color={colors.text.secondary} />
        </View>
      ) : null}

      {state === 'failed' ? (
        <View style={styles.overlay}>
          <Icon name="warning" size={28} color={colors.status.warning} />
          <Text variant="label" align="center">
            Couldn&apos;t display this photo
          </Text>
          <Text variant="caption" tone="secondary" align="center">
            Retake it or choose another. You can also continue and enter the amounts by hand.
          </Text>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  frame: {
    width: '100%',
    overflow: 'hidden',
    borderRadius: radii.lg,
    backgroundColor: colors.surface.raised,
    borderWidth: borderWidth.thin,
    borderColor: colors.surface.border,
  },
  image: { flex: 1 },
  overlay: {
    ...StyleSheet.absoluteFill,
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    padding: spacing.xl,
    backgroundColor: colors.surface.raised,
  },
});
