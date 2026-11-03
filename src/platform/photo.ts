/**
 * Camera and photo-library access — the platform boundary for bill photos.
 *
 * Both entry points return the same `PhotoResult`, so the camera and the
 * gallery feed one shared workflow (capture → preview → continue). Every
 * non-success outcome is an explicit case rather than a thrown exception, which
 * is what lets the UI give each one a proper message instead of a blank screen.
 *
 * Both go through `expo-image-picker`, which is bundled in Expo Go. The camera
 * path opens the system camera, not an in-app preview, so it behaves the same
 * in Expo Go as in a production build. Images stay on the device: nothing here
 * uploads anywhere.
 *
 * This is a platform integration, deliberately kept out of `src/core/`: it
 * imports a native module, and `src/core/` must run in plain Node.
 */

import * as ImagePicker from 'expo-image-picker';

import type { BillPhoto, PhotoSource } from '@/domain/photo';

export type PhotoResult =
  | { status: 'success'; photo: BillPhoto }
  | { status: 'cancelled' }
  /** `canAskAgain: false` means the OS will no longer show the prompt; the user must use Settings. */
  | { status: 'denied'; canAskAgain: boolean }
  | { status: 'error'; message: string };

/**
 * JPEG at 0.85 keeps a receipt legible while avoiding multi-megabyte HEIC/RAW
 * files, and re-encoding to JPEG sidesteps HEIC compatibility problems.
 * Cropping is off on purpose: iOS's editing UI is a square crop, which would
 * cut the bottom off a tall receipt.
 */
const PICKER_OPTIONS = {
  mediaTypes: ['images'],
  quality: 0.85,
  allowsEditing: false,
  exif: false,
} satisfies ImagePicker.ImagePickerOptions;

function toPhoto(result: ImagePicker.ImagePickerResult, source: PhotoSource): PhotoResult {
  if (result.canceled) return { status: 'cancelled' };

  const asset = result.assets?.[0];
  if (!asset?.uri) {
    return { status: 'error', message: 'No photo came back. Please try again.' };
  }

  return {
    status: 'success',
    photo: {
      uri: asset.uri,
      width: asset.width ?? 0,
      height: asset.height ?? 0,
      source,
      ...(asset.fileName ? { fileName: asset.fileName } : {}),
      ...(asset.mimeType ? { mimeType: asset.mimeType } : {}),
    },
  };
}

function describeError(error: unknown, source: PhotoSource): string {
  const detail = error instanceof Error ? error.message : String(error);

  // iOS Simulator (and some tablets) have no camera. Say so plainly rather
  // than surfacing a native error string.
  if (source === 'camera' && /simulator|not available|no camera|unavailable/i.test(detail)) {
    return "The camera isn't available on this device. Choose a photo from your library instead.";
  }

  return source === 'camera'
    ? "Couldn't open the camera. Please try again, or choose a photo from your library."
    : "Couldn't open your photo library. Please try again.";
}

/**
 * Opens the camera and returns the photo taken.
 *
 * Asks for camera permission first. If the user previously refused and iOS will
 * not prompt again, this returns `denied` with `canAskAgain: false` instead of
 * launching a camera that would fail.
 */
export async function takePhoto(): Promise<PhotoResult> {
  try {
    let permission = await ImagePicker.getCameraPermissionsAsync();

    if (!permission.granted) {
      if (!permission.canAskAgain) return { status: 'denied', canAskAgain: false };

      permission = await ImagePicker.requestCameraPermissionsAsync();
      if (!permission.granted) {
        return { status: 'denied', canAskAgain: permission.canAskAgain };
      }
    }

    const result = await ImagePicker.launchCameraAsync(PICKER_OPTIONS);
    return toPhoto(result, 'camera');
  } catch (error) {
    return { status: 'error', message: describeError(error, 'camera') };
  }
}

/**
 * Opens the photo library and returns the photo chosen.
 *
 * No permission request: on iOS the picker runs out-of-process (PHPicker), so
 * the app only ever receives the single photo the user selects and never needs
 * library access. That is also the more private design, and it means this path
 * cannot be blocked by a denied permission.
 */
export async function pickPhoto(): Promise<PhotoResult> {
  try {
    const result = await ImagePicker.launchImageLibraryAsync(PICKER_OPTIONS);
    return toPhoto(result, 'library');
  } catch (error) {
    return { status: 'error', message: describeError(error, 'library') };
  }
}
