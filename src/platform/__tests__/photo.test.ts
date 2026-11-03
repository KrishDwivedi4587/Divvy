import * as ImagePicker from 'expo-image-picker';

import { pickPhoto, takePhoto } from '../photo';

// The native module is replaced wholesale: these tests exercise the decision
// logic around it (permissions, cancellation, errors), not the camera itself.
jest.mock('expo-image-picker', () => ({
  getCameraPermissionsAsync: jest.fn(),
  requestCameraPermissionsAsync: jest.fn(),
  launchCameraAsync: jest.fn(),
  launchImageLibraryAsync: jest.fn(),
}));

const picker = jest.mocked(ImagePicker);

const permission = (granted: boolean, canAskAgain: boolean) =>
  ({
    granted,
    canAskAgain,
    status: granted ? 'granted' : canAskAgain ? 'undetermined' : 'denied',
    expires: 'never',
  }) as ImagePicker.PermissionResponse;

const asset = {
  uri: 'file:///var/mobile/bill.jpg',
  width: 3024,
  height: 4032,
  fileName: 'bill.jpg',
  mimeType: 'image/jpeg',
};

const picked = { canceled: false, assets: [asset] } as ImagePicker.ImagePickerResult;
const cancelled = { canceled: true, assets: null } as ImagePicker.ImagePickerResult;

describe('takePhoto', () => {
  it('launches the camera and returns the photo when permission is already granted', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(true, true));
    picker.launchCameraAsync.mockResolvedValue(picked);

    const result = await takePhoto();

    expect(result).toEqual({
      status: 'success',
      photo: {
        uri: asset.uri,
        width: 3024,
        height: 4032,
        source: 'camera',
        fileName: 'bill.jpg',
        mimeType: 'image/jpeg',
      },
    });
    expect(picker.requestCameraPermissionsAsync).not.toHaveBeenCalled();
  });

  it('asks for permission when it has not been decided, then launches', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(false, true));
    picker.requestCameraPermissionsAsync.mockResolvedValue(permission(true, true));
    picker.launchCameraAsync.mockResolvedValue(picked);

    const result = await takePhoto();

    expect(picker.requestCameraPermissionsAsync).toHaveBeenCalledTimes(1);
    expect(result.status).toBe('success');
  });

  it('reports denial, and that it can be asked again, when the user declines the prompt', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(false, true));
    picker.requestCameraPermissionsAsync.mockResolvedValue(permission(false, true));

    expect(await takePhoto()).toEqual({ status: 'denied', canAskAgain: true });
    expect(picker.launchCameraAsync).not.toHaveBeenCalled();
  });

  it('reports a permanent block without prompting or launching when iOS will not ask again', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(false, false));

    expect(await takePhoto()).toEqual({ status: 'denied', canAskAgain: false });
    expect(picker.requestCameraPermissionsAsync).not.toHaveBeenCalled();
    expect(picker.launchCameraAsync).not.toHaveBeenCalled();
  });

  it('reports a block that only appears after the prompt is refused', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(false, true));
    picker.requestCameraPermissionsAsync.mockResolvedValue(permission(false, false));

    expect(await takePhoto()).toEqual({ status: 'denied', canAskAgain: false });
  });

  it('reports cancellation when the user closes the camera', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(true, true));
    picker.launchCameraAsync.mockResolvedValue(cancelled);

    expect(await takePhoto()).toEqual({ status: 'cancelled' });
  });

  it('turns a thrown simulator error into a plain-language message', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(true, true));
    picker.launchCameraAsync.mockRejectedValue(new Error('Camera not available on simulator'));

    const result = await takePhoto();

    expect(result.status).toBe('error');
    if (result.status === 'error') {
      expect(result.message).toMatch(/isn't available/i);
      expect(result.message).not.toMatch(/simulator/i);
    }
  });

  it('turns any other launch failure into a generic retry message', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(true, true));
    picker.launchCameraAsync.mockRejectedValue(new Error('boom'));

    const result = await takePhoto();

    expect(result.status).toBe('error');
    if (result.status === 'error') expect(result.message).toMatch(/couldn't open the camera/i);
  });

  it('never throws, even when the permission check itself fails', async () => {
    picker.getCameraPermissionsAsync.mockRejectedValue(new Error('native module missing'));

    await expect(takePhoto()).resolves.toMatchObject({ status: 'error' });
  });

  it('treats a success with no asset as an error rather than a blank photo', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(true, true));
    picker.launchCameraAsync.mockResolvedValue({
      canceled: false,
      assets: [],
    } as unknown as ImagePicker.ImagePickerResult);

    expect(await takePhoto()).toMatchObject({ status: 'error' });
  });

  it('rejects an asset that has no uri', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(true, true));
    picker.launchCameraAsync.mockResolvedValue({
      canceled: false,
      assets: [{ ...asset, uri: '' }],
    } as ImagePicker.ImagePickerResult);

    expect(await takePhoto()).toMatchObject({ status: 'error' });
  });

  it('requests images only, uncropped, at reduced quality', async () => {
    picker.getCameraPermissionsAsync.mockResolvedValue(permission(true, true));
    picker.launchCameraAsync.mockResolvedValue(picked);

    await takePhoto();

    expect(picker.launchCameraAsync).toHaveBeenCalledWith(
      expect.objectContaining({ mediaTypes: ['images'], allowsEditing: false, quality: 0.85 }),
    );
  });
});

describe('pickPhoto', () => {
  it('returns the chosen photo, tagged as coming from the library', async () => {
    picker.launchImageLibraryAsync.mockResolvedValue(picked);

    const result = await pickPhoto();

    expect(result).toMatchObject({
      status: 'success',
      photo: { uri: asset.uri, source: 'library', width: 3024, height: 4032 },
    });
  });

  it('does not request library permission — the iOS picker needs none', async () => {
    picker.launchImageLibraryAsync.mockResolvedValue(picked);

    await pickPhoto();

    expect(picker.getCameraPermissionsAsync).not.toHaveBeenCalled();
    expect(picker.requestCameraPermissionsAsync).not.toHaveBeenCalled();
  });

  it('reports cancellation', async () => {
    picker.launchImageLibraryAsync.mockResolvedValue(cancelled);

    expect(await pickPhoto()).toEqual({ status: 'cancelled' });
  });

  it('turns a thrown error into a message instead of throwing', async () => {
    picker.launchImageLibraryAsync.mockRejectedValue(new Error('picker exploded'));

    const result = await pickPhoto();

    expect(result.status).toBe('error');
    if (result.status === 'error') expect(result.message).toMatch(/photo library/i);
  });

  it('omits file metadata the platform did not provide', async () => {
    picker.launchImageLibraryAsync.mockResolvedValue({
      canceled: false,
      assets: [{ uri: 'blob:abc', width: 0, height: 0 }],
    } as ImagePicker.ImagePickerResult);

    const result = await pickPhoto();

    expect(result.status).toBe('success');
    if (result.status === 'success') {
      expect(result.photo).toEqual({ uri: 'blob:abc', width: 0, height: 0, source: 'library' });
    }
  });

  it('requests images only', async () => {
    picker.launchImageLibraryAsync.mockResolvedValue(picked);

    await pickPhoto();

    expect(picker.launchImageLibraryAsync).toHaveBeenCalledWith(
      expect.objectContaining({ mediaTypes: ['images'] }),
    );
  });
});
