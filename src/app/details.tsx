import { useRouter } from 'expo-router';
import { useRef, useState } from 'react';
import { Pressable, StyleSheet, View, type TextInputInstance } from 'react-native';

import { formatPaise } from '@/core/money';
import { useGoBack } from '@/features/navigation/useGoBack';
import { useBillResult } from '@/features/bill/useBillResult';
import { ValueField } from '@/features/bill/ValueField';
import { PhotoReference } from '@/features/photo/PhotoReference';
import { MAX_CHARGES } from '@/store/billReducer';
import { useBill } from '@/store/BillProvider';
import { Button } from '@/ui/Button';
import { Card } from '@/ui/Card';
import { Icon } from '@/ui/Icon';
import { Notice } from '@/ui/Notice';
import { Screen } from '@/ui/Screen';
import { ScreenHeader } from '@/ui/ScreenHeader';
import { Text } from '@/ui/Text';
import { TextField } from '@/ui/TextField';
import { colors, layout, spacing } from '@/ui/theme/tokens';

/** The live total ignores the clock, so a fixed timestamp keeps it pure. */
const PREVIEW_NOW = '1970-01-01T00:00:00.000Z';

export default function Details() {
  const router = useRouter();
  const goBack = useGoBack();
  const { state, dispatch } = useBill();
  const outcome = useBillResult(PREVIEW_NOW);
  const [showErrors, setShowErrors] = useState(false);
  const amountRef = useRef<TextInputInstance>(null);

  // Errors stay hidden until the first attempt to continue, so the form does
  // not scold the user for fields they have not reached yet. After that they
  // update live as the user fixes them.
  const errors = showErrors && outcome.kind === 'invalid' ? outcome.build.errors : null;
  const total = outcome.kind === 'ready' ? formatPaise(outcome.settlement.grandTotal) : null;

  const onContinue = () => {
    if (outcome.kind === 'ready') router.push('/people');
    else setShowErrors(true);
  };

  const { draft } = state;

  return (
    <Screen
      header={
        <ScreenHeader
          title="Bill details"
          onBack={goBack}
          step={{ current: 2, total: 4, label: 'Details' }}
        />
      }
      footer={
        <View style={styles.footer}>
          <View style={styles.total}>
            <Text variant="caption" tone="muted">
              Total
            </Text>
            <Text variant="h2" tabular numberOfLines={1} adjustsFontSizeToFit>
              {total ?? '—'}
            </Text>
          </View>
          <View style={styles.continue}>
            <Button label="Continue" icon="arrowRight" onPress={onContinue} />
          </View>
        </View>
      }
    >
      {state.photo ? <PhotoReference photo={state.photo} /> : null}

      {outcome.kind === 'failed' ? (
        <Notice tone="error" title="Can't calculate this bill" message={outcome.message} />
      ) : null}

      <Card style={styles.card}>
        <TextField
          label="Bill name"
          value={draft.name}
          onChangeText={(text) => dispatch({ type: 'setName', text })}
          placeholder="e.g. Dinner at Toscana"
          returnKeyType="next"
          autoCapitalize="words"
          onSubmitEditing={() => amountRef.current?.focus()}
          helper="Optional"
        />
        <TextField
          label="Bill amount"
          value={draft.amountText}
          onChangeText={(text) => dispatch({ type: 'setAmount', text })}
          inputRef={amountRef}
          prefix="₹"
          placeholder="0.00"
          keyboardType="decimal-pad"
          inputMode="decimal"
          maxLength={11}
          error={errors?.amount}
          helper="The subtotal, before tax, tip and extra charges"
        />
      </Card>

      <Card style={styles.card}>
        <ValueField
          label="Tax"
          input={draft.tax}
          onChange={(patch) => dispatch({ type: 'setValue', target: 'tax', patch })}
          error={errors?.tax}
          helper="Calculated on the subtotal plus any extra charges"
        />
        <ValueField
          label="Tip"
          input={draft.tip}
          onChange={(patch) => dispatch({ type: 'setValue', target: 'tip', patch })}
          error={errors?.tip}
          helper="Calculated on the subtotal"
        />
      </Card>

      <View style={styles.section}>
        <Text variant="h3">Extra charges</Text>
        {draft.charges.length === 0 ? (
          <Text variant="bodySmall" tone="secondary">
            Service charge, packaging, delivery. Add any other line from the bill.
          </Text>
        ) : null}

        {draft.charges.map((charge, index) => (
          <Card key={charge.id} style={styles.card}>
            <View style={styles.chargeHeader}>
              <Text variant="label" tone="secondary">
                Charge {index + 1}
              </Text>
              <Pressable
                onPress={() => dispatch({ type: 'removeCharge', id: charge.id })}
                accessibilityRole="button"
                accessibilityLabel={`Remove charge ${index + 1}`}
                hitSlop={8}
                style={styles.remove}
              >
                <Icon name="trash" size={18} color={colors.text.secondary} />
              </Pressable>
            </View>
            <TextField
              label="Name"
              value={charge.label}
              onChangeText={(label) =>
                dispatch({ type: 'updateCharge', id: charge.id, patch: { label } })
              }
              placeholder="e.g. Service charge"
              autoCapitalize="sentences"
            />
            <ValueField
              label="Amount"
              input={charge}
              onChange={(patch) => dispatch({ type: 'updateCharge', id: charge.id, patch })}
              error={errors?.charges[charge.id]}
            />
          </Card>
        ))}

        <Button
          label={draft.charges.length === 0 ? 'Add a charge' : 'Add another charge'}
          icon="plus"
          variant="secondary"
          compact
          onPress={() => dispatch({ type: 'addCharge' })}
          disabled={draft.charges.length >= MAX_CHARGES}
        />
      </View>

      {errors ? (
        <Notice
          tone="error"
          message="Some details need attention. Check the highlighted fields above."
        />
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  card: { gap: spacing.lg },
  section: { gap: spacing.md },
  chargeHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  remove: {
    width: layout.minTouchTarget,
    height: layout.minTouchTarget,
    marginRight: -spacing.sm,
    alignItems: 'center',
    justifyContent: 'center',
  },
  footer: { flexDirection: 'row', alignItems: 'center', gap: spacing.lg },
  total: { flex: 1, gap: 2 },
  continue: { flex: 1 },
});
