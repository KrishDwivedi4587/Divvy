import { useRouter } from 'expo-router';
import { StyleSheet, View } from 'react-native';

import { CaptureProblemNotice } from '@/features/photo/CaptureProblemNotice';
import { usePhotoCapture } from '@/features/photo/usePhotoCapture';
import { RecentBills } from '@/features/bill/RecentBills';
import { useBill } from '@/store/BillProvider';
import { BrandMark } from '@/ui/BrandMark';
import { Button } from '@/ui/Button';
import { Card, Divider } from '@/ui/Card';
import { Icon } from '@/ui/Icon';
import { Screen } from '@/ui/Screen';
import { Text } from '@/ui/Text';
import { colors, layout, radii, spacing } from '@/ui/theme/tokens';

const STEPS = [
  { title: 'Capture the bill', detail: 'Photograph the receipt, or upload one you already have.' },
  { title: 'Add the details', detail: 'Enter the amount, plus any tax, tip and extra charges.' },
  { title: 'Add the people', detail: 'See exactly what each person owes, to the paisa.' },
] as const;

export default function Home() {
  const router = useRouter();
  const { state, dispatch } = useBill();
  const { busy, problem, capture } = usePhotoCapture();

  const startNewBill = () => {
    dispatch({ type: 'reset' });
    router.push('/capture');
  };

  // The secondary action: go straight to the gallery. It joins the same
  // workflow as the capture screen, so the user lands on the same preview.
  const uploadBill = async () => {
    dispatch({ type: 'reset' });
    if (await capture('library')) router.push('/preview');
  };

  return (
    <Screen contentStyle={styles.content}>
      <View style={styles.topBar}>
        <BrandMark />
      </View>

      <View style={styles.hero}>
        <Text variant="caption" tone="muted" style={styles.eyebrow}>
          BILL SPLITTING
        </Text>
        <Text variant="h1">Split the bill. Fairly.</Text>
        <Text variant="body" tone="secondary">
          Photograph a receipt, add the people, and see exactly what everyone owes.
        </Text>
      </View>

      <View style={styles.actions}>
        <Button label="New bill" icon="plus" onPress={startNewBill} disabled={busy !== null} />
        <Button
          label="Upload a bill photo"
          icon="photo"
          variant="secondary"
          onPress={uploadBill}
          loading={busy === 'library'}
          disabled={busy !== null}
        />
        {problem ? <CaptureProblemNotice problem={problem} /> : null}
      </View>

      <View style={styles.section}>
        <Text variant="h3">How it works</Text>
        <Card padding="none">
          {STEPS.map((step, index) => (
            <View key={step.title}>
              {index > 0 ? <Divider /> : null}
              <View style={styles.step}>
                <View style={styles.stepNumber}>
                  <Text variant="label" tone="secondary" tabular>
                    {index + 1}
                  </Text>
                </View>
                <View style={styles.stepCopy}>
                  <Text variant="body" style={styles.stepTitle}>
                    {step.title}
                  </Text>
                  <Text variant="bodySmall" tone="secondary">
                    {step.detail}
                  </Text>
                </View>
              </View>
            </View>
          ))}
        </Card>
      </View>

      <View style={styles.section}>
        <Text variant="h3">Recent bills</Text>
        <RecentBills bills={state.recent} />
      </View>

      <View style={styles.privacy}>
        <Icon name="lock" size={14} color={colors.text.muted} />
        <Text variant="caption" tone="muted">
          Photos stay on your device. Nothing is uploaded.
        </Text>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: { gap: spacing.xl },
  topBar: { paddingTop: spacing.sm },
  hero: { gap: spacing.md },
  eyebrow: { letterSpacing: 1.2 },
  actions: { gap: spacing.md },
  section: { gap: spacing.md },
  step: { flexDirection: 'row', gap: spacing.lg, padding: spacing.lg },
  stepNumber: {
    width: 28,
    height: 28,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: radii.pill,
    borderWidth: 1,
    borderColor: colors.surface.borderStrong,
  },
  stepCopy: { flex: 1, gap: 2 },
  stepTitle: { fontWeight: '700' },
  privacy: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: spacing.sm,
    paddingVertical: layout.screenPadding,
  },
});
