import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';

/// Determinate circular progress ring with a centered label (e.g. percent).
///
/// Visual only — tap handling belongs to the parent. Uses success/sage tokens
/// by default so it matches reading-progress chrome elsewhere.
class RdCircularProgress extends StatelessWidget {
  const RdCircularProgress({
    required this.value,
    required this.label,
    super.key,
    this.size = 52,
    this.strokeWidth = 4.5,
    this.color,
    this.trackColor,
    this.labelStyle,
  });

  /// 0.0–1.0 fill. Clamped.
  final double value;

  /// Centered text (typically `"42%"`).
  final String label;

  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progress = value.clamp(0.0, 1.0);
    final fg = color ?? c.success;
    final track =
        trackColor ?? Color.alphaBlend(fg.withValues(alpha: 0.18), c.surface1);
    final identity = ReadendarThemes.byId(
      context.readendarTheme.id,
    ).identity.effect;
    final premium = identity != ReadendarIdentityEffect.none;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        key: Key(
          identity == ReadendarIdentityEffect.ethereal
              ? 'etherealProgressConstellation'
              : premium
              ? 'premiumProgress-${identity.name}'
              : 'standardProgressRing',
        ),
        painter: identity == ReadendarIdentityEffect.ethereal
            ? _ConstellationRingPainter(
                progress: progress,
                color: c.accent,
                secondaryColor: c.accent2,
                trackColor: track,
                strokeWidth: strokeWidth,
              )
            : premium
            ? _IdentityRingPainter(
                identity: identity,
                progress: progress,
                color: c.accent,
                secondaryColor: c.accent2,
                trackColor: track,
                strokeWidth: strokeWidth,
              )
            : _RingPainter(
                progress: progress,
                color: fg,
                trackColor: track,
                strokeWidth: strokeWidth,
              ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style:
                labelStyle ??
                TextStyle(
                  fontSize: size < 48 ? 11 : 12,
                  fontWeight: FontWeight.w800,
                  color: c.successSoftFg,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _IdentityRingPainter extends CustomPainter {
  const _IdentityRingPainter({
    required this.identity,
    required this.progress,
    required this.color,
    required this.secondaryColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final ReadendarIdentityEffect identity;
  final double progress;
  final Color color;
  final Color secondaryColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth * 2) / 2;
    final segments = switch (identity) {
      ReadendarIdentityEffect.evercourt => 3,
      ReadendarIdentityEffect.stormbound => 8,
      ReadendarIdentityEffect.lastLight => 8,
      ReadendarIdentityEffect.trail => 10,
      ReadendarIdentityEffect.serpents => 13,
      ReadendarIdentityEffect.neonMoon => 10,
      ReadendarIdentityEffect.thornCrown => 11,
      ReadendarIdentityEffect.iridescent => 12,
      _ => 10,
    };
    final lit = (segments * progress).round().clamp(0, segments);
    final points = <Offset>[
      for (var index = 0; index < segments; index++)
        Offset(
          center.dx +
              math.cos(-math.pi / 2 + index * math.pi * 2 / segments) * radius,
          center.dy +
              math.sin(-math.pi / 2 + index * math.pi * 2 / segments) * radius,
        ),
    ];
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, strokeWidth * 0.35);
    final active = Paint()
      ..shader = SweepGradient(
        colors: identity == ReadendarIdentityEffect.iridescent
            ? [color, secondaryColor, color, secondaryColor, color]
            : [color, secondaryColor, color],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, strokeWidth * 0.62)
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < segments; index++) {
      final next = (index + 1) % segments;
      canvas.drawLine(
        points[index],
        points[next],
        index < lit ? active : track,
      );
    }
    for (var index = 0; index < segments; index++) {
      final markerColor = index < lit
          ? (index.isEven ? color : secondaryColor)
          : trackColor;
      final markerRadius = index < lit
          ? strokeWidth * (index % 3 == 0 ? 0.58 : 0.38)
          : 1.0;
      if (identity == ReadendarIdentityEffect.evercourt) {
        final marker = Path();
        for (var pointIndex = 0; pointIndex < 16; pointIndex++) {
          final angle = -math.pi / 2 + pointIndex * math.pi / 8;
          final pointRadius = pointIndex.isEven
              ? markerRadius * (pointIndex % 4 == 0 ? 1.55 : 0.9)
              : markerRadius * 0.32;
          final markerPoint =
              points[index] +
              Offset(math.cos(angle), math.sin(angle)) * pointRadius;
          if (pointIndex == 0) {
            marker.moveTo(markerPoint.dx, markerPoint.dy);
          } else {
            marker.lineTo(markerPoint.dx, markerPoint.dy);
          }
        }
        marker.close();
        canvas.drawPath(marker, Paint()..color = markerColor);
      } else {
        canvas.drawCircle(
          points[index],
          markerRadius,
          Paint()..color = markerColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IdentityRingPainter oldDelegate) =>
      oldDelegate.identity != identity ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _ConstellationRingPainter extends CustomPainter {
  const _ConstellationRingPainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color secondaryColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth * 2) / 2;
    const stars = 14;
    final lit = (stars * progress).round().clamp(0, stars);
    final points = <Offset>[
      for (var index = 0; index < stars; index++)
        Offset(
          center.dx +
              math.cos(-math.pi / 2 + index * math.pi * 2 / stars) * radius,
          center.dy +
              math.sin(-math.pi / 2 + index * math.pi * 2 / stars) * radius,
        ),
    ];
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, strokeWidth * 0.38);
    final activePaint = Paint()
      ..shader = LinearGradient(
        colors: [color, secondaryColor],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, strokeWidth * 0.58)
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < stars; index++) {
      final next = (index + 1) % stars;
      canvas.drawLine(
        points[index],
        points[next],
        index < lit && next <= lit ? activePaint : trackPaint,
      );
    }
    for (var index = 0; index < stars; index++) {
      final active = index < lit;
      final pointPaint = Paint()
        ..color = active ? (index.isEven ? color : secondaryColor) : trackColor;
      canvas.drawCircle(
        points[index],
        active && index % 4 == 0 ? strokeWidth * 0.62 : strokeWidth * 0.4,
        pointPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// Convenience: ring sized for book-detail cockpit (~52px) using design tokens.
abstract final class RdCircularProgressSizes {
  static const double bookDetail = 52;
  static const double bookDetailStroke = 4.5;
}
