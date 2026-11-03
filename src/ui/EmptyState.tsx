import { StyleSheet, View } from 'react-native';

import { Button } from '@/ui/Button';
import { Icon, type IconName } from '@/ui/Icon';
import { Text } from '@/ui/Text';
import { borderWidth, colors, radii, spacing } from '@/ui/theme/tokens';

export interface EmptyStateProps {
  icon: IconName;
  title: string;
  message: string;
  action?: { label: string; onPress: () => void; icon?: IconName };
}

export function EmptyState({ icon, title, message, action }: EmptyStateProps) {
  return (
    <View style={styles.container}>
      <View style={styles.badge}>
        <Icon name={icon} size={24} color={colors.text.secondary} />
      </View>
      <View style={styles.copy}>
        <Text variant="h3" align="center">
          {title}
        </Text>
        <Text variant="bodySmall" tone="secondary" align="center">
          {message}
        </Text>
      </View>
      {action ? (
        <Button
          label={action.label}
          icon={action.icon}
          onPress={action.onPress}
          variant="secondary"
          compact
        />
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: 'center', gap: spacing.lg, paddingVertical: spacing.xl },
  badge: {
    width: 56,
    height: 56,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radii.pill,
    backgroundColor: colors.surface.elevated,
    borderWidth: borderWidth.thin,
    borderColor: colors.surface.borderStrong,
  },
  copy: { gap: spacing.sm, maxWidth: 280 },
});
