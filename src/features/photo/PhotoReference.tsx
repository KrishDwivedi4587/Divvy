import { Image } from 'expo-image';
import { useState } from 'react';
import { Modal, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import type { BillPhoto } from '@/domain/photo';
import { Card } from '@/ui/Card';
import { Icon } from '@/ui/Icon';
import { Text } from '@/ui/Text';
import { borderWidth, colors, layout, radii, spacing } from '@/ui/theme/tokens';

/**
 * The bill photo, kept on screen as a reference while the user types the
 * figures. Divvy does not read the photo automatically yet, so having it one tap
 * away is what makes manual entry quick (roadmap §1 D1: the photo is a
 * convenience, never load-bearing).
 */
export function PhotoReference({ photo }: { photo: BillPhoto }) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <Pressable
        onPress={() => setOpen(true)}
        accessibilityRole="button"
        accessibilityLabel="View bill photo full screen"
      >
        {({ pressed }) => (
          <Card padding="md" style={[styles.row, pressed && styles.pressed]}>
            <Image
              source={{ uri: photo.uri }}
              style={styles.thumb}
              contentFit="cover"
              accessibilityIgnoresInvertColors
            />
            <View style={styles.copy}>
              <Text variant="label">Bill photo attached</Text>
              <Text variant="caption" tone="muted">
                Tap to view while you enter the amounts
              </Text>
            </View>
            <Icon name="chevronRight" size={16} color={colors.text.muted} />
          </Card>
        )}
      </Pressable>

      <PhotoViewerModal photo={photo} visible={open} onClose={() => setOpen(false)} />
    </>
  );
}

function PhotoViewerModal({
  photo,
  visible,
  onClose,
}: {
  photo: BillPhoto;
  visible: boolean;
  onClose: () => void;
}) {
  const insets = useSafeAreaInsets();

  return (
    <Modal visible={visible} animationType="fade" onRequestClose={onClose} statusBarTranslucent>
      <View style={styles.viewer}>
        <Image
          source={{ uri: photo.uri }}
          style={styles.full}
          contentFit="contain"
          accessibilityLabel="Bill photo"
        />
        <Pressable
          onPress={onClose}
          accessibilityRole="button"
          accessibilityLabel="Close photo"
          hitSlop={8}
          style={[styles.close, { top: insets.top + spacing.md }]}
        >
          <Icon name="close" size={18} />
        </Pressable>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  pressed: { backgroundColor: colors.surface.elevated },
  thumb: {
    width: 44,
    height: 56,
    borderRadius: radii.sm,
    backgroundColor: colors.surface.elevated,
  },
  copy: { flex: 1, gap: 2 },
  viewer: { flex: 1, backgroundColor: colors.surface.background },
  full: { flex: 1 },
  close: {
    position: 'absolute',
    right: layout.screenPadding,
    width: layout.minTouchTarget,
    height: layout.minTouchTarget,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radii.pill,
    backgroundColor: colors.surface.raised,
    borderWidth: borderWidth.thin,
    borderColor: colors.surface.borderStrong,
  },
});
