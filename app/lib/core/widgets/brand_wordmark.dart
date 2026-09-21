import 'package:flutter/material.dart';

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({
    required this.label,
    this.style,
    this.textAlign,
    super.key,
  });

  final String label;
  final TextStyle? style;
  final TextAlign? textAlign;

  static const _prefix = 'Read';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final suffix = label.startsWith(_prefix)
        ? label.substring(_prefix.length)
        : '';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: label.startsWith(_prefix) ? _prefix : label,
            style: TextStyle(color: colorScheme.primary),
          ),
          if (suffix.isNotEmpty)
            TextSpan(
              text: suffix,
              style: TextStyle(color: colorScheme.onSurface),
            ),
        ],
      ),
      textAlign: textAlign,
      semanticsLabel: label,
      style: effectiveStyle,
    );
  }
}
