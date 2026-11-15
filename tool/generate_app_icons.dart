// Generates Divvy's app icons from the brand mark, drawn in code.
//
// Run from the project root (it needs Flutter's drawing engine, so it runs as
// a test):
//
//     flutter test tool/generate_app_icons.dart
//
// It rewrites every PNG in the iOS AppIcon set (sizes read from its
// Contents.json) and the Android launcher icons. The mark is the same two
// overlapping circles as the BrandMark widget: one solid, one outlined.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const int _ink = 0xFF0B0B0B;
const int _paper = 0xFFF5F5F3;

/// The launch screen sits on an off-white page, so its mark is drawn in ink.
/// Must match LaunchScreen.storyboard's declared image size (168 x 185 pt).
const double _launchWidth = 168;
const double _launchHeight = 185;

void _paint(ui.Canvas canvas, double s) {
  // iOS applies its own rounded mask, so the icon is a full-bleed square.
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, s, s),
    ui.Paint()..color = const ui.Color(_ink),
  );

  final width = s * 0.58; // total width of the mark
  final d = width * 0.72; // circle diameter, as in BrandMark
  final gap = width * 0.06;
  final left = (s - width) / 2;
  final top = (s - d) / 2;
  final r = d / 2;
  final cy = top + r;

  final light = ui.Paint()..color = const ui.Color(_paper);
  final dark = ui.Paint()..color = const ui.Color(_ink);

  canvas.drawCircle(ui.Offset(left + r, cy), r, light);
  // A dark gap around the right circle cuts a crescent out of the left one.
  final cx = left + width - r;
  canvas.drawCircle(ui.Offset(cx, cy), r + gap, dark);
  canvas.drawCircle(ui.Offset(cx, cy), r, light);
}

void _paintLaunch(ui.Canvas canvas, double w, double h) {
  // Transparent background; the mark centred, 60% of the image width.
  final width = w * 0.6;
  final d = width * 0.72;
  final gap = width * 0.06;
  final left = (w - width) / 2;
  final r = d / 2;
  final cy = h / 2;
  final ink = ui.Paint()..color = const ui.Color(_ink);

  final cx = left + width - r;
  // Cut the gap with a clear circle, not a painted one, so the page shows
  // through.
  canvas
    ..saveLayer(ui.Rect.fromLTWH(0, 0, w, h), ui.Paint())
    ..drawCircle(ui.Offset(left + r, cy), r, ink)
    ..drawCircle(
      ui.Offset(cx, cy),
      r + gap,
      ui.Paint()..blendMode = ui.BlendMode.clear,
    )
    ..drawCircle(ui.Offset(cx, cy), r, ink)
    ..restore();
}

Future<void> _writeLaunch(String path, int scale) async {
  final w = (_launchWidth * scale).round();
  final h = (_launchHeight * scale).round();
  final recorder = ui.PictureRecorder();
  _paintLaunch(
    ui.Canvas(recorder)..scale(scale.toDouble()),
    _launchWidth,
    _launchHeight,
  );
  final image = await recorder.endRecording().toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// CRC-32 as PNG chunks require.
final List<int> _crcTable = () {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}();

int _crc(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

List<int> _chunk(String type, List<int> data) {
  final body = [...type.codeUnits, ...data];
  final out = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
    ..add(body)
    ..add((ByteData(4)..setUint32(0, _crc(body))).buffer.asUint8List());
  return out.toBytes();
}

/// Encodes opaque RGBA pixels as an RGB PNG with no alpha channel. The App
/// Store rejects an app icon that has one, even if every pixel is opaque, and
/// Flutter's own encoder always writes RGBA.
Uint8List _encodeRgbPng(int size, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw.addByte(0); // filter type: none
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      raw
        ..addByte(rgba[i])
        ..addByte(rgba[i + 1])
        ..addByte(rgba[i + 2]);
    }
  }
  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2); // colour type: RGB
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
    ..._chunk('IHDR', header.buffer.asUint8List()),
    ..._chunk('IDAT', ZLibEncoder().convert(raw.toBytes())),
    ..._chunk('IEND', const []),
  ]);
}

Future<void> _write(String path, int pixels, {bool alpha = true}) async {
  final recorder = ui.PictureRecorder();
  _paint(ui.Canvas(recorder), pixels.toDouble());
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final Uint8List png;
  if (alpha) {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    png = bytes!.buffer.asUint8List();
  } else {
    final rgba = await image.toByteData();
    png = _encodeRgbPng(pixels, rgba!.buffer.asUint8List());
  }
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png);
}

void main() {
  test('generate app icons', () async {
    // ---- iOS: every file the AppIcon set lists ---------------------------
    const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    final manifest = jsonDecode(
      File('$iosDir/Contents.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    var count = 0;
    for (final entry in manifest['images'] as List<dynamic>) {
      final image = entry as Map<String, dynamic>;
      final name = image['filename'] as String?;
      if (name == null) continue;
      final points = double.parse((image['size'] as String).split('x').first);
      final scale = int.parse((image['scale'] as String).replaceAll('x', ''));
      await _write('$iosDir/$name', (points * scale).round(), alpha: false);
      count++;
    }

    // ---- Android launcher icons -------------------------------------------
    const android = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };
    for (final e in android.entries) {
      await _write(
        'android/app/src/main/res/mipmap-${e.key}/ic_launcher.png',
        e.value,
      );
      count++;
    }

    // ---- iOS launch screen mark -------------------------------------------
    const launchDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
    await _writeLaunch('$launchDir/LaunchImage.png', 1);
    await _writeLaunch('$launchDir/LaunchImage@2x.png', 2);
    await _writeLaunch('$launchDir/LaunchImage@3x.png', 3);
    count += 3;

    expect(count, greaterThan(20));
  });
}
