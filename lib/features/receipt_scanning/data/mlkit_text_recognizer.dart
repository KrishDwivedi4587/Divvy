import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;

import '../domain/recognized_text.dart';
import '../domain/text_recognizer.dart';

/// Recognises text with Google ML Kit, running entirely on the device: the
/// photo is never uploaded.
///
/// ML Kit returns text blocks, lines and elements with their positions. Only
/// lines, with their rotated corner points, are passed on; the parser puts
/// them back into rows itself.
class MlKitTextRecognizer implements ReceiptTextRecognizer {
  MlKitTextRecognizer()
    : _recognizer = mlkit.TextRecognizer(
        script: mlkit.TextRecognitionScript.latin,
      );

  final mlkit.TextRecognizer _recognizer;

  @override
  Future<RecognizedText> recognize(String imagePath) async {
    try {
      final result = await _recognizer.processImage(
        mlkit.InputImage.fromFilePath(imagePath),
      );
      return convert(result);
    } catch (e) {
      throw TextRecognitionException('$e');
    }
  }

  /// Converts ML Kit's result into the parser's input type. Public so the
  /// conversion can be tested with hand-built ML Kit objects.
  static RecognizedText convert(mlkit.RecognizedText result) {
    final lines = <OcrLine>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        lines.add(
          OcrLine(
            line.text,
            _corners(line),
            // Only Android reports a per-line confidence; on iOS it is null.
            confidence: line.confidence,
          ),
        );
      }
    }
    return RecognizedText(lines: lines, rawText: result.text);
  }

  static List<OcrPoint> _corners(mlkit.TextLine line) {
    final points = line.cornerPoints;
    if (points.length == 4) {
      return [for (final p in points) OcrPoint(p.x.toDouble(), p.y.toDouble())];
    }
    // Fall back to the upright box if the corners are missing.
    final r = line.boundingBox;
    return [
      OcrPoint(r.left, r.top),
      OcrPoint(r.right, r.top),
      OcrPoint(r.right, r.bottom),
      OcrPoint(r.left, math.max(r.bottom, r.top)),
    ];
  }

  @override
  Future<void> dispose() => _recognizer.close();
}
