import { Linking, Platform } from 'react-native';

import type { CaptureProblem } from '@/features/photo/usePhotoCapture';
import { Notice } from '@/ui/Notice';

export interface CaptureProblemNoticeProps {
  problem: CaptureProblem;
  /** Retry the camera, when the problem was a refusable prompt. */
  onRetryCamera?: () => void;
}

/**
 * Turns a failed capture into guidance the user can act on. A permission
 * refusal in particular is not a dead end: the notice points to the gallery,
 * which needs no permission, and to Settings when iOS will no longer prompt.
 */
export function CaptureProblemNotice({ problem, onRetryCamera }: CaptureProblemNoticeProps) {
  if (problem.kind === 'error') {
    return <Notice tone="error" title="Something went wrong" message={problem.message} />;
  }

  const canOpenSettings = Platform.OS !== 'web';

  if (problem.canAskAgain) {
    return (
      <Notice
        tone="warning"
        title="Camera access needed"
        message="Divvy needs the camera to photograph your bill. You can allow it, or upload a photo from your gallery instead."
        actions={onRetryCamera ? [{ label: 'Try again', onPress: onRetryCamera }] : undefined}
      />
    );
  }

  return (
    <Notice
      tone="warning"
      title="Camera access is off"
      message={
        canOpenSettings
          ? 'Turn camera access on in Settings to take a photo, or upload one from your gallery instead.'
          : 'Allow camera access in your browser settings to take a photo, or upload one from your gallery instead.'
      }
      actions={
        canOpenSettings
          ? [{ label: 'Open Settings', onPress: () => void Linking.openSettings() }]
          : undefined
      }
    />
  );
}
