import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Share, StyleSheet, View } from 'react-native';

import { formatPaise } from '@/core/money';
import { adjustmentLabel, formatDate, peopleCount } from '@/features/bill/format';
import { PersonResultCard } from '@/features/bill/PersonResultCard';
import { buildShareText } from '@/features/bill/shareText';
import { useBillResult } from '@/features/bill/useBillResult';
import { useGoBack } from '@/features/navigation/useGoBack';
import { PhotoReference } from '@/features/photo/PhotoReference';
import { useBill } from '@/store/BillProvider';
import { Button } from '@/ui/Button';
import { Card, Divider } from '@/ui/Card';
import { EmptyState } from '@/ui/EmptyState';
import { Notice } from '@/ui/Notice';
import { Screen } from '@/ui/Screen';
import { ScreenHeader } from '@/ui/ScreenHeader';
import { Text } from '@/ui/Text';
import { spacing } from '@/ui/theme/tokens';

export default function Summary() {
  const router = useRouter();
  const goBack = useGoBack();
  const { state, dispatch } = useBill();

  // Captured once, when the summary opens, so the date shown is the date saved.
  const [now] = useState(() => new Date().toISOString());
  const outcome = useBillResult(now);

  const [saved, setSaved] = useState(false);
  const [shareError, setShareError] = useState(false);

  const header = (
    <ScreenHeader
      title="Summary"
      onBack={goBack}
      step={{ current: 4, total: 4, label: 'Summary' }}
    />
  );

  // The bill is incomplete (e.g. a reload cleared it). Say so and offer the way
  // back, rather than showing zeros.
  if (outcome.kind === 'invalid') {
    return (
      <Screen header={header}>
        <EmptyState
          icon="receipt"
          title="Bill details are incomplete"
          message="Enter the bill amount to see how it splits."
          action={{ label: 'Go to details', onPress: () => router.replace('/details') }}
        />
      </Screen>
    );
  }

  if (outcome.kind === 'failed') {
    return (
      <Screen header={header}>
        <Notice tone="error" title="Can't calculate this bill" message={outcome.message} />
        <Button label="Edit details" variant="secondary" onPress={goBack} />
      </Screen>
    );
  }

  const { bill } = outcome.build;
  const { settlement } = outcome;

  const labels = new Map(bill.adjustments.map((a) => [a.id, adjustmentLabel(a)]));
  const people = new Map(bill.people.map((p) => [p.id, p]));

  // The engine asserts this on every settlement. If it ever fails, show no
  // money at all: a wrong figure on a bill is worse than none.
  if (!settlement.reconciles) {
    return (
      <Screen header={header}>
        <Notice
          tone="error"
          title="These figures don't add up"
          message="Something is wrong with this bill, so no amounts are shown. Go back and check your details."
        />
        <Button label="Edit details" variant="secondary" onPress={goBack} />
      </Screen>
    );
  }

  const onShare = async () => {
    setShareError(false);
    try {
      await Share.share({ message: buildShareText(bill, settlement) });
    } catch {
      setShareError(true);
    }
  };

  const onSave = () => {
    if (saved) return;
    setSaved(true);
    dispatch({
      type: 'saveBill',
      bill: {
        id: now,
        title: bill.title,
        createdAt: now,
        total: settlement.grandTotal,
        peopleCount: bill.people.length,
        ...(state.photo ? { photoUri: state.photo.uri } : {}),
      },
    });
    // Back to Home, dropping the capture-to-summary screens off the stack.
    if (router.canDismiss()) router.dismissAll();
    else router.replace('/');
  };

  return (
    <Screen
      header={header}
      footer={
        <>
          <Button label="Save & finish" icon="check" onPress={onSave} disabled={saved} />
          <Button label="Share summary" icon="share" variant="secondary" onPress={onShare} />
        </>
      }
    >
      <Card style={styles.hero}>
        <Text variant="label" tone="secondary" numberOfLines={1}>
          {bill.title}
        </Text>
        <View style={styles.heroTotal}>
          <Text variant="caption" tone="muted">
            Total bill
          </Text>
          <Text variant="display" tabular numberOfLines={1} adjustsFontSizeToFit>
            {formatPaise(settlement.grandTotal)}
          </Text>
        </View>
        <Text variant="bodySmall" tone="secondary">
          Split equally between {peopleCount(bill.people.length)} · {formatDate(bill.createdAt)}
        </Text>
      </Card>

      {shareError ? (
        <Notice tone="warning" message="Sharing isn't available here. Try again on your phone." />
      ) : null}

      <View style={styles.section}>
        <Text variant="h3">Each person pays</Text>
        {settlement.perPerson.map((result) => {
          const person = people.get(result.personId);
          return person ? (
            <PersonResultCard key={person.id} person={person} result={result} labels={labels} />
          ) : null;
        })}
      </View>

      <View style={styles.section}>
        <Text variant="h3">Bill breakdown</Text>
        <Card padding="none">
          <View style={styles.breakdown}>
            <BreakdownLine label="Subtotal" value={formatPaise(settlement.itemsSubtotal)} />
            {settlement.adjustmentTotals.map((adjustment) => (
              <BreakdownLine
                key={adjustment.adjustmentId}
                label={labels.get(adjustment.adjustmentId) ?? 'Charge'}
                value={formatPaise(adjustment.amount)}
              />
            ))}
          </View>
          <Divider />
          <View style={styles.breakdown}>
            <BreakdownLine label="Total" value={formatPaise(settlement.grandTotal)} strong />
          </View>
        </Card>
      </View>

      {state.photo ? <PhotoReference photo={state.photo} /> : null}
    </Screen>
  );
}

function BreakdownLine({
  label,
  value,
  strong = false,
}: {
  label: string;
  value: string;
  strong?: boolean;
}) {
  return (
    <View style={styles.line}>
      <Text
        variant={strong ? 'body' : 'bodySmall'}
        tone={strong ? 'primary' : 'secondary'}
        style={strong ? styles.strong : null}
      >
        {label}
      </Text>
      <Text
        variant={strong ? 'body' : 'bodySmall'}
        tone={strong ? 'primary' : 'secondary'}
        tabular
        style={strong ? styles.strong : null}
      >
        {value}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  hero: { gap: spacing.md },
  heroTotal: { gap: spacing.xs },
  section: { gap: spacing.md },
  breakdown: { padding: spacing.lg, gap: spacing.md },
  line: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  strong: { fontWeight: '700' },
});
