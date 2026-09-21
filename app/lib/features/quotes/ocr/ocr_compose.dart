import 'dart:ui';

/// One recognized text line, in image-pixel coordinate space (display-upright /
/// post-EXIF). [index] is the traversal order — reading order for normal book
/// pages.
class OcrLine {
  const OcrLine({required this.index, required this.text, required this.rect});
  final int index;
  final String text;
  final Rect rect;
}

/// Maps a normalized `[0, 1]` top-left box into image-pixel space.
Rect normalizedBoxToPixels(Rect normalized, double width, double height) {
  return Rect.fromLTWH(
    normalized.left * width,
    normalized.top * height,
    normalized.width * width,
    normalized.height * height,
  );
}

/// Builds [OcrLine]s from recognizer output: emission order → [OcrLine.index],
/// normalized boxes → pixel [OcrLine.rect] using [width]/[height].
List<OcrLine> buildOcrLines({
  required Iterable<(String text, Rect normalizedBox)> lines,
  required double width,
  required double height,
}) {
  var i = 0;
  return [
    for (final (text, box) in lines)
      OcrLine(
        index: i++,
        text: text,
        rect: normalizedBoxToPixels(box, width, height),
      ),
  ];
}

/// Composes the selected lines into the quote text: reading order, joined
/// with single spaces, and end-of-line hyphenation merged (a line ending in
/// "-" glues to the next selected line without the hyphen, restoring the
/// split word).
String composeOcrSelection(List<OcrLine> lines, Set<int> selected) {
  final chosen = lines.where((l) => selected.contains(l.index)).toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  var out = '';
  for (final line in chosen) {
    final t = line.text.trim();
    if (t.isEmpty) continue;
    if (out.isEmpty) {
      out = t;
    } else if (out.endsWith('-')) {
      out = out.substring(0, out.length - 1) + t;
    } else {
      out = '$out $t';
    }
  }
  return out;
}
