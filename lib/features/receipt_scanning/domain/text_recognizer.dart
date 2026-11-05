import 'recognized_text.dart';

/// Reads the text off a photo. Implemented over Google ML Kit in `data/`; tests
/// supply a fake so nothing here needs a camera or a phone.
abstract interface class ReceiptTextRecognizer {
  /// Recognises the text in the image file at [imagePath]. Throws
  /// [TextRecognitionException] if recognition itself fails; returning empty
  /// text is not a failure, it just means nothing was found.
  Future<RecognizedText> recognize(String imagePath);

  Future<void> dispose();
}

class TextRecognitionException implements Exception {
  const TextRecognitionException(this.message);

  final String message;

  @override
  String toString() => 'TextRecognitionException: $message';
}
