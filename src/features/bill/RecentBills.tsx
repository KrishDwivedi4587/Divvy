import { Image } from 'expo-image';
import { StyleSheet, View } from 'react-native';

import { formatPaise } from '@/core/money';
import { formatDate, peopleCount } from '@/features/bill/format';
import type { SavedBill } from '@/store/billReducer';
import type { Paise } from '@/domain/types';
import { Card, Divider } from '@/ui/Card';
import { EmptyState } from '@/ui/EmptyState';
import { Icon } from '@/ui/Icon';
import { Text } from '@/ui/Text';
import { colors, radii, spacing } from '@/ui/theme/tokens';

export function RecentBills({ bills }: { bills: readonly SavedBill[] }) {
  if (bills.length === 0) {
    return (
      <Card>
        <EmptyState
          icon="receipt"
          title="No bills yet"
          message="Bills you finish appear here for this session. Start one to see how it works."
        />
      </Card>
    );
  }

  return (
    <Card padding="none">
      {bills.map((bill, index) => (
        <View key={bill.id}>
          {index > 0 ? <Divider /> : null}
          <View style={styles.row}>
            {bill.photoUri ? (
              <Image source={{ uri: bill.photoUri }} style={styles.thumb} contentFit="cover" />
            ) : (
              <View style={[styles.thumb, styles.thumbEmpty]}>
                <Icon name="receipt" size={18} color={colors.text.muted} />
              </View>
            )}
            <View style={styles.copy}>
              <Text variant="body" numberOfLines={1} style={styles.title}>
                {bill.title}
              </Text>
              <Text variant="caption" tone="muted">
                {formatDate(bill.createdAt)} · {peopleCount(bill.peopleCount)}
              </Text>
            </View>
            <Text variant="body" tabular style={styles.title}>
              {formatPaise(bill.total as Paise)}
            </Text>
          </View>
        </View>
      ))}
    </Card>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.lg,
  },
  thumb: { width: 40, height: 48, borderRadius: radii.sm },
  thumbEmpty: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.surface.elevated,
  },
  copy: { flex: 1, gap: 2 },
  title: { fontWeight: '700' },
});
