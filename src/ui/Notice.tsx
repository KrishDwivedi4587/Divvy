import { StyleSheet, View } from 'react-native';

import { Button } from '@/ui/Button';
import { Icon, type IconName } from '@/ui/Icon';
import { Text } from '@/ui/Text';
import { colors, radii, spacing, tint } from '@/ui/theme/tokens';

export type NoticeTone = 'info' | 'warning' | 'error' | 'success';

const ICON: Record<NoticeTone, IconName> = {
  info: 'info',
  warning: 'warning',
  error: 'warning',
  success: 'checkCircle',
};

export interface NoticeProps {
  tone?: NoticeTone;
  title?: string;
  message: string;
  actions?: { label: string; onPress: () => void }[];
}

/**
 * An inline message. Every notice has an icon and words as well as a tint, so
 * its meaning never depends on colour alone.
 */
export function Notice({ tone = 'info', title, message, actions }: NoticeProps) {
  const accent = colors.status[tone];

  return (
    <View
      style={[styles.notice, { backgroundColor: tint[tone] }]}
      accessibilityRole={tone === 'error' ? 'alert' : undefined}
      accessibilityLiveRegion={tone === 'error' ? 'polite' : undefined}
    >
      <View style={styles.row}>
        <View style={styles.icon}>
          <Icon name={ICON[tone]} size={20} color={accent} />
        </View>
        <View style={styles.body}>
          {title ? <Text variant="label">{title}</Text> : null}
          <Text variant="bodySmall" tone="secondary">
            {message}
          </Text>
        </View>
      </View>

      {actions && actions.length > 0 ? (
        <View style={styles.actions}>
          {actions.map((action) => (
            <Button
              key={action.label}
              label={action.label}
              onPress={action.onPress}
              variant="secondary"
              compact
            />
          ))}
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  notice: {
    borderRadius: radii.md,
    padding: spacing.md,
    gap: spacing.md,
  },
  row: { flexDirection: 'row', gap: spacing.md },
  icon: { paddingTop: 1 },
  body: { flex: 1, gap: spacing.xs },
  actions: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
});
