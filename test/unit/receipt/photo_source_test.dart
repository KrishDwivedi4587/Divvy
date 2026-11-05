import 'package:divvy/features/receipt_scanning/data/image_picker_photo_source.dart';
import 'package:divvy/features/receipt_scanning/domain/receipt_photo_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

ImagePickerPhotoSource source(PickImage pick) =>
    ImagePickerPhotoSource(pick: pick);

PickImage throwing(String code, [String? message]) =>
    (_) async => throw PlatformException(code: code, message: message);

void main() {
  group('camera', () {
    test('returns the photo taken, tagged as from the camera', () async {
      PhotoSource? asked;
      final r = await source((s) async {
        asked = s;
        return '/tmp/photo.jpg';
      }).takePhoto();

      expect(asked, PhotoSource.camera);
      expect(r, isA<PhotoPicked>());
      expect((r as PhotoPicked).path, '/tmp/photo.jpg');
      expect(r.source, PhotoSource.camera);
    });

    test('reports cancellation when the user closes the camera', () async {
      final r = await source((_) async => null).takePhoto();
      expect(r, isA<PhotoCancelled>());
    });

    test('reports a refused camera permission as denied', () async {
      for (final code in ['camera_access_denied', 'camera_access_restricted']) {
        final r = await source(throwing(code)).takePhoto();
        expect(r, isA<PhotoDenied>(), reason: code);
      }
    });

    test('turns a missing camera into a plain-language message', () async {
      for (final failure in [
        throwing('no_available_camera'),
        throwing('unknown', 'Camera is not available on the simulator'),
      ]) {
        final r = await source(failure).takePhoto();
        expect(r, isA<PhotoFailed>());
        expect((r as PhotoFailed).message, contains("isn't available"));
        expect(r.message, contains('photo from your library'));
      }
    });

    test('turns any other platform error into a retry message', () async {
      final r = await source(throwing('weird', 'boom')).takePhoto();
      expect((r as PhotoFailed).message, contains("Couldn't open the camera"));
      expect(r.message, isNot(contains('boom')));
    });

    test('never throws, even for an unexpected exception type', () async {
      final r = await source((_) async => throw StateError('x')).takePhoto();
      expect(r, isA<PhotoFailed>());
    });

    test('treats an empty path as a failure, not a blank photo', () async {
      final r = await source((_) async => '').takePhoto();
      expect((r as PhotoFailed).message, contains('No photo came back'));
    });
  });

  group('gallery', () {
    test('returns the chosen photo, tagged as from the gallery', () async {
      PhotoSource? asked;
      final r = await source((s) async {
        asked = s;
        return '/tmp/chosen.jpg';
      }).pickFromGallery();

      expect(asked, PhotoSource.gallery);
      expect((r as PhotoPicked).source, PhotoSource.gallery);
    });

    test('reports cancellation', () async {
      final r = await source((_) async => null).pickFromGallery();
      expect(r, isA<PhotoCancelled>());
    });

    test('turns an error into a message instead of throwing', () async {
      final r = await source(throwing('boom')).pickFromGallery();
      expect((r as PhotoFailed).message, contains('photo library'));
    });

    test(
      'a library refusal is a failure with guidance, not a camera block',
      () async {
        final r = await source(throwing('photo_access_denied'))
            .pickFromGallery();
        expect(r, isA<PhotoFailed>());
        expect((r as PhotoFailed).message, contains('photo access'));
      },
    );
  });
}
