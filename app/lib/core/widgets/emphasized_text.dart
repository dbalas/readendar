import 'package:flutter/material.dart';

/// Renders [text] with `**bold**` markers as medium-weight spans.
///
/// Markers are translation-owned (each locale wraps the words that should
/// stand out). Unmatched `**` are left as literal text.
class EmphasizedText extends StatelessWidget {
  const EmphasizedText(
    this.text, {
    super.key,
    this.style,
    this.emphasisStyle,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? emphasisStyle;

  @visibleForTesting
  static List<InlineSpan> spansFor(
    String text, {
    TextStyle? style,
    TextStyle? emphasisStyle,
  }) {
    final bold =
        emphasisStyle ??
        style?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontWeight: FontWeight.w600);
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var start = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: style),
        );
      }
      spans.add(TextSpan(text: match.group(1), style: bold));
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: style));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: spansFor(
          text,
          style: style,
          emphasisStyle: emphasisStyle,
        ),
      ),
    );
  }
}
