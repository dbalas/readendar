import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';

/// Determinate progress that inherits a premium theme's progress metaphor.
///
/// Standard themes keep Material's quiet bar. Ethereal uses a constellation
/// path whose lit stars increase with real reading progress; it never invents
/// activity and remains fully static.
class ThemedLinearProgress extends StatelessWidget {
  const ThemedLinearProgress({
    required this.value,
    this.minHeight = 5,
    this.indicatorKey,
    super.key,
  });

  final double value;
  final double minHeight;
  final Key? indicatorKey;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0);
    final colors = context.colors;
    final identity = ReadendarThemes.byId(
      context.readendarTheme.id,
    ).identity.effect;
    if (identity == ReadendarIdentityEffect.none) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          key: indicatorKey,
          minHeight: minHeight,
          value: progress,
          backgroundColor: colors.accentSoftBg,
          color: colors.accent,
        ),
      );
    }
    if (identity == ReadendarIdentityEffect.ethereal) {
      return KeyedSubtree(
        key: indicatorKey,
        child: SizedBox(
          key: const Key('etherealLinearProgress'),
          height: math.max(7, minHeight),
          child: CustomPaint(
            painter: _ConstellationLinePainter(
              progress: progress,
              color: colors.accent,
              secondaryColor: colors.accent2,
              trackColor: colors.line,
            ),
          ),
        ),
      );
    }
    return KeyedSubtree(
      key: indicatorKey,
      child: SizedBox(
        key: Key('premiumLinearProgress-${identity.name}'),
        height: math.max(7, minHeight),
        child: CustomPaint(
          painter: _IdentityLinePainter(
            identity: identity,
            progress: progress,
            color: colors.accent,
            secondaryColor: colors.accent2,
            trackColor: colors.line,
          ),
        ),
      ),
    );
  }
}

class _IdentityLinePainter extends CustomPainter {
  const _IdentityLinePainter({
    required this.identity,
    required this.progress,
    required this.color,
    required this.secondaryColor,
    required this.trackColor,
  });

  final ReadendarIdentityEffect identity;
  final double progress;
  final Color color;
  final Color secondaryColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = switch (identity) {
      ReadendarIdentityEffect.stormbound => 8,
      ReadendarIdentityEffect.evercourt => 3,
      ReadendarIdentityEffect.neonMoon => 10,
      ReadendarIdentityEffect.trail => 10,
      ReadendarIdentityEffect.serpents => 13,
      ReadendarIdentityEffect.thornCrown => 11,
      ReadendarIdentityEffect.iridescent => 12,
      ReadendarIdentityEffect.lastLight => 8,
      _ => 9,
    };
    final lit = (nodes * progress).round().clamp(0, nodes);
    final points = <Offset>[
      for (var index = 0; index < nodes; index++)
        Offset(
          index * size.width / (nodes - 1),
          size.height * _height(index, nodes),
        ),
    ];
    final track = Paint()
      ..color = trackColor
      ..strokeWidth = 1;
    final active = Paint()
      ..shader = LinearGradient(
        colors: identity == ReadendarIdentityEffect.iridescent
            ? [color, secondaryColor, color]
            : [color, secondaryColor],
      ).createShader(Offset.zero & size)
      ..strokeWidth = identity == ReadendarIdentityEffect.neonMoon ? 2 : 1.6
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < nodes - 1; index++) {
      canvas.drawLine(
        points[index],
        points[index + 1],
        index < lit - 1 ? active : track,
      );
    }
    for (var index = 0; index < nodes; index++) {
      final markerColor = index < lit
          ? (index.isEven ? color : secondaryColor)
          : trackColor;
      final markerRadius = index < lit ? (index % 3 == 0 ? 2.2 : 1.35) : 1.0;
      if (identity == ReadendarIdentityEffect.evercourt) {
        final marker = Path();
        for (var pointIndex = 0; pointIndex < 16; pointIndex++) {
          final angle = -math.pi / 2 + pointIndex * math.pi / 8;
          final pointRadius = pointIndex.isEven
              ? markerRadius * (pointIndex % 4 == 0 ? 1.65 : 0.95)
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

  double _height(int index, int count) => switch (identity) {
    ReadendarIdentityEffect.stormbound => index.isEven ? 0.76 : 0.2,
    ReadendarIdentityEffect.evercourt => index == 1 ? 0.16 : 0.76,
    ReadendarIdentityEffect.neonMoon => index.isEven ? 0.68 : 0.5,
    ReadendarIdentityEffect.trail => index.isEven ? 0.68 : 0.34,
    ReadendarIdentityEffect.serpents =>
      0.5 + math.sin(index * math.pi * 3 / count) * 0.3,
    ReadendarIdentityEffect.thornCrown => 0.5 + math.sin(index * 0.85) * 0.22,
    ReadendarIdentityEffect.iridescent => 0.5 + math.sin(index * 0.62) * 0.3,
    ReadendarIdentityEffect.lastLight => index % 4 == 0 ? 0.25 : 0.68,
    _ => 0.5,
  };

  @override
  bool shouldRepaint(covariant _IdentityLinePainter oldDelegate) =>
      oldDelegate.identity != identity ||
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.trackColor != trackColor;
}

class _ConstellationLinePainter extends CustomPainter {
  const _ConstellationLinePainter({
    required this.progress,
    required this.color,
    required this.secondaryColor,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color secondaryColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stars = 9;
    final lit = (stars * progress).round().clamp(0, stars);
    final points = <Offset>[
      for (var index = 0; index < stars; index++)
        Offset(
          index * size.width / (stars - 1),
          size.height * (index.isEven ? 0.62 : 0.34),
        ),
    ];
    final track = Paint()
      ..color = trackColor
      ..strokeWidth = 1;
    final active = Paint()
      ..shader = LinearGradient(
        colors: [color, secondaryColor],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < stars - 1; index++) {
      canvas.drawLine(
        points[index],
        points[index + 1],
        index < lit - 1 ? active : track,
      );
    }
    for (var index = 0; index < stars; index++) {
      final enabled = index < lit;
      canvas.drawCircle(
        points[index],
        enabled && index % 3 == 0 ? 2.1 : 1.35,
        Paint()
          ..color = enabled
              ? (index.isEven ? color : secondaryColor)
              : trackColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationLinePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.secondaryColor != secondaryColor ||
      oldDelegate.trackColor != trackColor;
}
