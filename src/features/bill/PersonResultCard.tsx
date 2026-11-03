import { useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';

import { formatPaise } from '@/core/money';
import type { Paise, Person, PersonSettlement } from '@/domain/types';
import { Avatar } from '@/ui/Avatar';
import { Card, Divider } from '@/ui/Card';
import { Icon } from '@/ui/Icon';
import { Text } from '@/ui/Text';
import { colors, spacing } from '@/ui/theme/tokens';

export interface PersonResultCardProps {
  person: Person;
  result: PersonSettlement;
  /** adjustment id → display label (e.g. "Tax · 5%"). */
  labels: ReadonlyMap<string, string>;
}

/**
 * One person's share. Collapsed it shows what they owe and a one-line
 * explanation; expanded it itemises exactly where every paisa comes from, using
 * the figures the calculation engine produced — nothing is recomputed here.
 */
export function PersonResultCard({ person, result, labels }: PersonResultCardProps) {
  const [open, setOpen] = useState(false);

  const extras = (result.total - result.subtotal) as Paise;
  const hasExtras = result.adjustmentShares.length > 0;

  return (
    <Card padding="none">
      <Pressable
        onPress={() => setOpen((o) => !o)}
        accessibilityRole="button"
        accessibilityLabel={`${person.name} owes ${formatPaise(result.total)}`}
        accessibilityHint={open ? 'Hide breakdown' : 'Show breakdown'}
        accessibilityState={{ expanded: open }}
        style={({ pressed }) => [styles.header, pressed && styles.pressed]}
      >
        <Avatar initials={person.initials} colorIndex={person.colorIndex} size="lg" />

        <View style={styles.who}>
          <Text variant="body" style={styles.name} numberOfLines={1}>
            {person.name}
          </Text>
          <Text variant="caption" tone="muted" tabular numberOfLines={1}>
            {hasExtras
              ? `${formatPaise(result.subtotal)} + ${formatPaise(extras)} extras`
              : `${formatPaise(result.subtotal)} share of the bill`}
          </Text>
        </View>

        <View style={styles.amount}>
          <Text variant="h2" tabular>
            {formatPaise(result.total)}
          </Text>
          <Icon name={open ? 'chevronUp' : 'chevronDown'} size={14} color={colors.text.muted} />
        </View>
      </Pressable>

      {open ? (
        <View>
          <Divider />
          <View style={styles.breakdown}>
            <Line label="Share of the bill" value={result.subtotal} />
            {result.adjustmentShares.map((share) => (
              <Line
                key={share.adjustmentId}
                label={labels.get(share.adjustmentId) ?? 'Charge'}
                value={share.share}
              />
            ))}
            <Divider />
            <Line label="Total" value={result.total} strong />
          </View>
        </View>
      ) : null}
    </Card>
  );
}

function Line({ label, value, strong = false }: { label: string; value: Paise; strong?: boolean }) {
  return (
    <View style={styles.line}>
      <Text
        variant="bodySmall"
        tone={strong ? 'primary' : 'secondary'}
        style={strong ? styles.strong : null}
      >
        {label}
      </Text>
      <Text
        variant="bodySmall"
        tone={strong ? 'primary' : 'secondary'}
        tabular
        style={strong ? styles.strong : null}
      >
        {formatPaise(value)}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.lg,
  },
  pressed: { backgroundColor: colors.surface.elevated },
  who: { flex: 1, gap: 2 },
  name: { fontWeight: '700' },
  amount: { alignItems: 'flex-end', gap: spacing.xs },
  breakdown: { padding: spacing.lg, gap: spacing.md },
  line: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  strong: { fontWeight: '700' },
});
