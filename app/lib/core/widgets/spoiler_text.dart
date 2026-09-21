import 'package:flutter/material.dart';
import 'package:readendar/core/theme/app_colors.dart';

/// Inline Telegram-style particle veil that preserves the wrapped text layout.
///
/// Only computed line bounds are painted. Parent surfaces, icons, padding, and
/// adjacent metadata remain visible. The concealed text is excluded from
/// semantics until the owner replaces this widget after [onReveal].
class RdSpoilerText extends StatelessWidget {
  const RdSpoilerText({
    required this.text,
    required this.semanticsLabel,
    required this.onReveal,
    this.style,
    this.maxLines,
    this.particlesKey,
    super.key,
  });

  final String text;
  final String semanticsLabel;
  final TextStyle? style;
  final VoidCallback onReveal;
  final int? maxLines;
  final Key? particlesKey;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onReveal,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: RepaintBoundary(
            child: CustomPaint(
              key: particlesKey,
              isComplex: true,
              foregroundPainter: _SpoilerTextPainter(
                text: text,
                style: effectiveStyle,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                locale: Localizations.maybeLocaleOf(context),
                maxLines: maxLines,
                veil: colors.fg3.withValues(alpha: 0.20),
                particle: colors.fg2.withValues(alpha: 0.58),
                glint: colors.accent.withValues(alpha: 0.36),
              ),
              child: ExcludeSemantics(
                child: Text(
                  text,
                  maxLines: maxLines,
                  overflow: maxLines == null
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: effectiveStyle.copyWith(color: Colors.transparent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpoilerTextPainter extends CustomPainter {
  const _SpoilerTextPainter({
    required this.text,
    required this.style,
    required this.textDirection,
    required this.textScaler,
    required this.locale,
    required this.maxLines,
    required this.veil,
    required this.particle,
    required this.glint,
  });

  final String text;
  final TextStyle style;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final Locale? locale;
  final int? maxLines;
  final Color veil;
  final Color particle;
  final Color glint;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      locale: locale,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: size.width);
    final veilPaint = Paint()..color = veil;
    final particlePaint = Paint()..color = particle;
    final glintPaint = Paint()..color = glint;
    final textSeed = text.codeUnits.fold<int>(
      17,
      (seed, unit) => seed * 31 + unit,
    );

    for (final line in layout.computeLineMetrics()) {
      if (line.width <= 0) continue;
      final rect = Rect.fromLTWH(
        line.left,
        line.baseline - line.ascent + 1,
        line.width,
        (line.ascent + line.descent - 2).clamp(1.0, double.infinity),
      );
      final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rounded, veilPaint);
      canvas.save();
      canvas.clipRRect(rounded);
      const step = 5.0;
      for (var y = rect.top; y < rect.bottom; y += step) {
        for (var x = rect.left; x < rect.right; x += step) {
          final hash = (x.floor() * 37) ^ (y.floor() * 61) ^ textSeed;
          if (hash % 4 == 0) continue;
          final radius = 1.15 + (hash.abs() % 4) * 0.35;
          final offset = Offset(
            x + ((hash >> 2) & 3) * 0.55,
            y + ((hash >> 5) & 3) * 0.55,
          );
          canvas.drawCircle(
            offset,
            radius,
            hash % 9 == 0 ? glintPaint : particlePaint,
          );
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SpoilerTextPainter oldDelegate) =>
      oldDelegate.text != text ||
      oldDelegate.style != style ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textScaler != textScaler ||
      oldDelegate.locale != locale ||
      oldDelegate.maxLines != maxLines ||
      oldDelegate.veil != veil ||
      oldDelegate.particle != particle ||
      oldDelegate.glint != glint;
}
