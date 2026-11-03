import { StyleSheet, View } from 'react-native';

import { Text } from '@/ui/Text';
import { avatarSize, AVATAR_COLOR_COUNT, colors } from '@/ui/theme/tokens';

export interface AvatarProps {
  initials: string;
  /** Index into the fixed 8-colour palette. Wraps if out of range. */
  colorIndex: number;
  size?: keyof typeof avatarSize;
}

/**
 * A person is always identified by initials as well as colour: the palette's
 * reds, oranges and ambers converge under common colour-vision deficiencies, so
 * colour alone must never be the identifier (roadmap D3, docs/design-tokens.md).
 */
export function Avatar({ initials, colorIndex, size = 'md' }: AvatarProps) {
  const dimension = avatarSize[size];
  const index = ((colorIndex % AVATAR_COLOR_COUNT) + AVATAR_COLOR_COUNT) % AVATAR_COLOR_COUNT;

  return (
    <View
      style={[
        styles.avatar,
        {
          width: dimension,
          height: dimension,
          borderRadius: dimension / 2,
          backgroundColor: colors.avatar[index],
        },
      ]}
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
    >
      <Text
        variant={size === 'sm' ? 'caption' : size === 'md' ? 'label' : 'body'}
        tone="inverse"
        style={styles.initials}
      >
        {initials}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  avatar: { alignItems: 'center', justifyContent: 'center' },
  initials: { fontWeight: '700' },
});
