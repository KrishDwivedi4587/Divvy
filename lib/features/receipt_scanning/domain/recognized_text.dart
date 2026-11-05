/// What a text recogniser hands to the receipt parser.
///
/// These are plain value types. The ML Kit adapter converts its own classes
/// into them, so the parser (and its tests) never import a plugin.
library;

import 'dart:math' as math;

class OcrPoint {
  const OcrPoint(this.x, this.y);

  final double x;
  final double y;
}

/// One recognised line of text and where it sits on the photo.
class OcrLine {
  /// [corners] are the four corners in reading order: top-left, top-right,
  /// bottom-right, bottom-left. They are rotated along with the text, which is
  /// how a tilted photo is detected.
  const OcrLine(this.text, this.corners, {this.confidence});

  /// An upright box, for tests and for recognisers that give no corners.
  factory OcrLine.box(
    String text, {
    required double left,
    required double top,
    required double width,
    double height = 20,
    double? confidence,
  }) {
    return OcrLine(text, [
      OcrPoint(left, top),
      OcrPoint(left + width, top),
      OcrPoint(left + width, top + height),
      OcrPoint(left, top + height),
    ], confidence: confidence);
  }

  final String text;
  final List<OcrPoint> corners;

  /// The recogniser's own confidence, 0..1, when it reports one.
  final double? confidence;

  OcrPoint get center => OcrPoint(
    corners.fold<double>(0, (s, c) => s + c.x) / corners.length,
    corners.fold<double>(0, (s, c) => s + c.y) / corners.length,
  );

  double get width => _dist(corners[0], corners[1]);
  double get height => _dist(corners[0], corners[3]);

  /// The direction the text runs, in radians (0 = level).
  double get angle =>
      math.atan2(corners[1].y - corners[0].y, corners[1].x - corners[0].x);

  static double _dist(OcrPoint a, OcrPoint b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
}

/// The output of recognising one photo.
class RecognizedText {
  const RecognizedText({required this.lines, required this.rawText});

  /// Builds upright lines from plain text, one per row. For tests and manual
  /// paste; real recognisers supply geometry.
  factory RecognizedText.fromPlainText(String text) {
    final rows = text.split('\n');
    return RecognizedText(
      rawText: text,
      lines: [
        for (var i = 0; i < rows.length; i++)
          if (rows[i].trim().isNotEmpty)
            OcrLine.box(
              rows[i],
              left: 0,
              top: i * 30.0,
              width: rows[i].length * 10.0,
              height: 20,
            ),
      ],
    );
  }

  final List<OcrLine> lines;

  /// The text exactly as the recogniser returned it, kept for debugging.
  final String rawText;

  bool get isEmpty => lines.every((l) => l.text.trim().isEmpty);
}

/// Lines that sit on the same visual row of the receipt, left to right. A
/// receipt's item name and its price are usually separate recognised lines
/// (separate columns), so they have to be put back together by position.
class OcrRow {
  const OcrRow(this.parts);

  final List<OcrLine> parts;

  String get text => parts.map((p) => p.text.trim()).join(' ').trim();
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Groups recognised lines into visual rows, top to bottom.
///
/// A photographed receipt is rarely level. When the text is tilted, the price
/// column drifts up or down relative to the item names, and grouping by raw
/// height would pair a price with the wrong item. So the skew is estimated from
/// the lines themselves (the median baseline angle of the wide lines) and every
/// position is rotated back before rows are formed.
List<OcrRow> groupIntoRows(RecognizedText recognized) {
  final lines = recognized.lines
      .where((l) => l.text.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return const [];

  // Short lines give noisy angles; only trust ones clearly wider than tall.
  final reliable = lines.where((l) => l.width > 2.5 * l.height).toList();
  var skew = _median([for (final l in reliable) l.angle]);
  // Below half a degree the correction is noise.
  if (skew.abs() < 0.5 * math.pi / 180) skew = 0;

  final cosA = math.cos(skew);
  final sinA = math.sin(skew);
  // Rotate by -skew: levels the baselines.
  double levelX(OcrPoint p) => p.x * cosA + p.y * sinA;
  double levelY(OcrPoint p) => -p.x * sinA + p.y * cosA;

  final heights = [for (final l in lines) l.height].where((h) => h > 0);
  final lineHeight = _median(heights.toList());
  final tolerance = (lineHeight == 0 ? 10 : lineHeight) * 0.5;

  final placed = [
    for (final l in lines) (line: l, x: levelX(l.center), y: levelY(l.center)),
  ]..sort((a, b) => a.y.compareTo(b.y));

  final rows = <List<({OcrLine line, double x, double y})>>[];
  var rowCenter = 0.0;
  for (final item in placed) {
    if (rows.isNotEmpty && (item.y - rowCenter).abs() <= tolerance) {
      rows.last.add(item);
      rowCenter =
          rows.last.fold<double>(0, (s, e) => s + e.y) / rows.last.length;
    } else {
      rows.add([item]);
      rowCenter = item.y;
    }
  }

  return [
    for (final row in rows)
      OcrRow([
        for (final e in [...row]..sort((a, b) => a.x.compareTo(b.x))) e.line,
      ]),
  ];
}
