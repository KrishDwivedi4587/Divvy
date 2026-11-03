import { useRouter } from 'expo-router';
import { StyleSheet, View } from 'react-native';

import { useGoBack } from '@/features/navigation/useGoBack';
import { CaptureProblemNotice } from '@/features/photo/CaptureProblemNotice';
import { PhotoPreviewImage } from '@/features/photo/PhotoPreviewImage';
import { usePhotoCapture } from '@/features/photo/usePhotoCapture';
import { useBill } from '@/store/BillProvider';
import { Button } from '@/ui/Button';
import { EmptyState } from '@/ui/EmptyState';
import { Screen } from '@/ui/Screen';
import { ScreenHeader } from '@/ui/ScreenHeader';
import { Text } from '@/ui/Text';
import { spacing } from '@/ui/theme/tokens';

export default function Preview() {
  const router = useRouter();
  const goBack = useGoBack();
  const { dispatch } = useBill();
  const { photo, busy, problem, capture } = usePhotoCapture();

  const header = (
    <ScreenHeader
      title="Check the photo"
      onBack={goBack}
      step={{ current: 1, total: 4, label: 'Photo' }}
    />
  );

  // Reached without a photo (a reload, or a deep link): offer a way forward
  // rather than a blank screen.
  if (!photo) {
    return (
      <Screen header={header}>
        <EmptyState
          icon="camera"
          title="No photo yet"
          message="Take a photo of your bill or upload one to see it here."
          action={{ label: 'Add a photo', onPress: () => router.replace('/capture') }}
        />
      </Screen>
    );
  }

  const fromCamera = photo.source === 'camera';
  const dimensions =
    photo.width > 0 && photo.height > 0 ? `${photo.width} × ${photo.height}` : null;

  return (
    <Screen
      header={header}
      footer={
        <>
          <Button
            label="Use this photo"
            icon="arrowRight"
            onPress={() => router.push('/details')}
            disabled={busy !== null}
          />
          <View style={styles.secondary}>
            <View style={styles.flex}>
              <Button
                label={fromCamera ? 'Retake photo' : 'Choose another'}
                icon={fromCamera ? 'retake' : 'photo'}
                variant="secondary"
                compact
                onPress={() => void capture(photo.source)}
                loading={busy !== null}
              />
            </View>
            <View style={styles.flex}>
              <Button
                label="Remove"
                icon="trash"
                variant="ghost"
                compact
                disabled={busy !== null}
                onPress={() => {
                  dispatch({ type: 'setPhoto', photo: null });
                  goBack();
                }}
              />
            </View>
          </View>
        </>
      }
    >
      <PhotoPreviewImage key={photo.uri} photo={photo} />

      <View style={styles.meta}>
        <Text variant="caption" tone="muted">
          {fromCamera ? 'Taken with camera' : 'From your gallery'}
          {dimensions ? ` · ${dimensions}` : ''}
        </Text>
      </View>

      {problem ? (
        <CaptureProblemNotice problem={problem} onRetryCamera={() => void capture('camera')} />
      ) : null}
    </Screen>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  secondary: { flexDirection: 'row', gap: spacing.sm },
  meta: { alignItems: 'center' },
});
