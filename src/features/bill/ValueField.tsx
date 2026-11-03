import type { TextInput } from 'react-native';
import type { Ref } from 'react';

import type { ValueInput, ValueMode } from '@/core/buildBill';
import { SegmentedControl, type SegmentOption } from '@/ui/SegmentedControl';
import { TextField } from '@/ui/TextField';

const MODES: readonly SegmentOption<ValueMode>[] = [
  { value: 'percent', label: '%', accessibilityLabel: 'Percent' },
  { value: 'amount', label: '₹', accessibilityLabel: 'Rupees' },
];

export interface ValueFieldProps {
  label: string;
  input: ValueInput;
  onChange: (patch: Partial<ValueInput>) => void;
  error?: string;
  helper?: string;
  inputRef?: Ref<TextInput>;
}

/**
 * A number the user can express either as a percentage of the bill or as a flat
 * rupee amount. Used for tax, tip and each extra charge.
 */
export function ValueField({ label, input, onChange, error, helper, inputRef }: ValueFieldProps) {
  return (
    <TextField
      label={label}
      value={input.text}
      onChangeText={(text) => onChange({ text })}
      error={error}
      helper={helper}
      inputRef={inputRef}
      prefix={input.mode === 'amount' ? '₹' : undefined}
      placeholder={input.mode === 'amount' ? '0.00' : '0'}
      keyboardType="decimal-pad"
      inputMode="decimal"
      maxLength={11}
      accessory={
        <SegmentedControl
          options={MODES}
          value={input.mode}
          onChange={(mode) => onChange({ mode })}
        />
      }
    />
  );
}
