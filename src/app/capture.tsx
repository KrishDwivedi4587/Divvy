import { useRouter } from 'expo-router';
import { StyleSheet, View } from 'react-native';

import { useGoBack } from '@/features/navigation/useGoBack';
import { CaptureProblemNotice } from '@/features/photo/CaptureProblemNotice';
import { SourceOption } from '@/features/photo/SourceOption';
import { usePhotoCapture } from '@/features/photo/usePhotoCapture';
import { Button } from '@/ui/Button';
import { Card } from '@/ui/Card';
import { Screen } from '@/ui/Screen';
import { ScreenHeader } from '@/ui/ScreenHeader';
import { Text } from '@/ui/Text';
import { colors, spacing } from '@/ui/theme/tokens';

const TIPS = [
  'Lay the receipt flat on a plain surface.',
  'Use good light and avoid shadows across the text.',
  'Keep the whole receipt in frame, including the total.',
] as const;

export default function Capture() {
  const router = useRouter();
  const goBack = useGoBack();
  const { busy, problem, capture } = usePhotoCapture();

  // Both sources share one path: whichever the user picks, a stored photo means
  // we move on to the same preview.
  const choose = async (source: 'camera' | 'library') => {
    if (await capture(source)) router.push('/preview');
  };

  return (
    <Screen
      header={
        <ScreenHeader
          title="New bill"
          onBack={goBack}
          step={{ current: 1, total: 4, label: 'Photo' }}
        />
      }
    >
      <View style={styles.intro}>
        <Text variant="h2">Add your bill</Text>
        <Text variant="body" tone="secondary">
          Take a photo of the receipt or upload one. You can keep it on screen while you enter the
          amounts.
        </Text>
      </View>

      <View style={styles.options}>
        <SourceOption
          icon="camera"
          title="Take photo"
          description="Use your camera to photograph the bill"
          onPress={() => void choose('camera')}
          loading={busy === 'camera'}
          disabled={busy !== null}
          testID="take-photo"
        />
        <SourceOption
          icon="photo"
          title="Upload from gallery"
          description="Choose a photo you already have"
          onPress={() => void choose('library')}
          loading={busy === 'library'}
          disabled={busy !== null}
          testID="upload-photo"
        />
      </View>

      {problem ? (
        <CaptureProblemNotice problem={problem} onRetryCamera={() => void choose('camera')} />
      ) : null}

      <Card style={styles.tips}>
        <Text variant="label">For a clear photo</Text>
        {TIPS.map((tip) => (
          <View key={tip} style={styles.tip}>
            <View style={styles.bullet} />
            <Text variant="bodySmall" tone="secondary" style={styles.tipText}>
              {tip}
            </Text>
          </View>
        ))}
      </Card>

      <View style={styles.manual}>
        <Text variant="caption" tone="muted" align="center">
          No receipt to hand?
        </Text>
        <Button
          label="Enter details manually"
          variant="ghost"
          icon="edit"
          onPress={() => router.push('/details')}
          disabled={busy !== null}
        />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  intro: { gap: spacing.sm },
  options: { gap: spacing.md },
  tips: { gap: spacing.md },
  tip: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.md },
  bullet: {
    width: 5,
    height: 5,
    marginTop: 8,
    borderRadius: 3,
    backgroundColor: colors.text.muted,
  },
  tipText: { flex: 1 },
  manual: { alignItems: 'center', gap: spacing.xs },
});
