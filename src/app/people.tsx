import { useRouter } from 'expo-router';
import { useRef, useState } from 'react';
import { Pressable, StyleSheet, View, type TextInput } from 'react-native';

import {
  checkPersonName,
  initialsFor,
  MAX_NAME_LENGTH,
  MAX_PEOPLE,
  type NameCheckFailure,
} from '@/core/people';
import { useGoBack } from '@/features/navigation/useGoBack';
import { useBill } from '@/store/BillProvider';
import { Avatar } from '@/ui/Avatar';
import { Button } from '@/ui/Button';
import { Card, Divider } from '@/ui/Card';
import { Icon } from '@/ui/Icon';
import { Notice } from '@/ui/Notice';
import { Screen } from '@/ui/Screen';
import { ScreenHeader } from '@/ui/ScreenHeader';
import { Text } from '@/ui/Text';
import { TextField } from '@/ui/TextField';
import { colors, layout, spacing } from '@/ui/theme/tokens';

const MIN_TO_SPLIT = 2;

const NAME_ERRORS: Record<NameCheckFailure, string> = {
  empty: 'Enter a name',
  duplicate: 'That name is already on the list',
  'too-long': `Names can be up to ${MAX_NAME_LENGTH} characters`,
  limit: `You can split between up to ${MAX_PEOPLE} people`,
};

export default function People() {
  const router = useRouter();
  const goBack = useGoBack();
  const { state, dispatch } = useBill();
  const { people } = state;

  const [name, setName] = useState('');
  const [error, setError] = useState<string | undefined>();
  const inputRef = useRef<TextInput>(null);

  const add = () => {
    const check = checkPersonName(
      name,
      people.map((p) => p.name),
    );
    if (!check.ok) {
      setError(NAME_ERRORS[check.reason]);
      return;
    }
    dispatch({ type: 'addPerson', name: check.name });
    setName('');
    setError(undefined);
    inputRef.current?.focus();
  };

  const enough = people.length >= MIN_TO_SPLIT;

  return (
    <Screen
      header={
        <ScreenHeader
          title="Who's splitting?"
          onBack={goBack}
          step={{ current: 3, total: 4, label: 'People' }}
        />
      }
      footer={
        <>
          {!enough ? (
            <Text variant="caption" tone="muted" align="center">
              Add at least {MIN_TO_SPLIT} people to split the bill
            </Text>
          ) : null}
          <Button
            label="See summary"
            icon="arrowRight"
            onPress={() => router.push('/summary')}
            disabled={!enough}
          />
        </>
      }
    >
      <View style={styles.addRow}>
        <View style={styles.addField}>
          <TextField
            label="Add a person"
            value={name}
            onChangeText={(text) => {
              setName(text);
              if (error) setError(undefined);
            }}
            inputRef={inputRef}
            placeholder="Name"
            returnKeyType="done"
            autoCapitalize="words"
            autoCorrect={false}
            maxLength={MAX_NAME_LENGTH + 4}
            onSubmitEditing={add}
            error={error}
          />
        </View>
        <View style={styles.addButton}>
          <Button
            label="Add"
            icon="plus"
            compact
            onPress={add}
            disabled={people.length >= MAX_PEOPLE}
          />
        </View>
      </View>

      <View style={styles.section}>
        <View style={styles.sectionHeader}>
          <Text variant="h3">Participants</Text>
          <Text variant="caption" tone="muted" tabular>
            {people.length} of {MAX_PEOPLE}
          </Text>
        </View>

        <Card padding="none">
          {people.map((person, index) => (
            <View key={person.id}>
              {index > 0 ? <Divider /> : null}
              <View style={styles.row}>
                <Avatar initials={initialsFor(person.name)} colorIndex={person.colorIndex} />
                <Text variant="body" style={styles.name} numberOfLines={1}>
                  {person.name}
                </Text>
                <Pressable
                  onPress={() => dispatch({ type: 'removePerson', id: person.id })}
                  disabled={people.length <= 1}
                  accessibilityRole="button"
                  accessibilityLabel={`Remove ${person.name}`}
                  accessibilityState={{ disabled: people.length <= 1 }}
                  hitSlop={8}
                  style={[styles.remove, people.length <= 1 && styles.removeDisabled]}
                >
                  <Icon name="close" size={16} color={colors.text.secondary} />
                </Pressable>
              </View>
            </View>
          ))}
        </Card>
      </View>

      <Notice
        tone="info"
        message="Everyone pays an equal share of the bill. Splitting by individual item is planned for a later version."
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  addRow: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.md },
  addField: { flex: 1 },
  // Lines the button up with the input, below the field's label.
  addButton: { marginTop: 26 },
  section: { gap: spacing.md },
  sectionHeader: { flexDirection: 'row', alignItems: 'baseline', justifyContent: 'space-between' },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
  },
  name: { flex: 1, fontWeight: '700' },
  remove: {
    width: layout.minTouchTarget,
    height: layout.minTouchTarget,
    marginRight: -spacing.sm,
    alignItems: 'center',
    justifyContent: 'center',
  },
  removeDisabled: { opacity: 0.38 },
});
