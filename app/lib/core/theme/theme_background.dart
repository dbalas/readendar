import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:readendar/core/theme/theme_catalog.dart';

@visibleForTesting
Offset premiumThemeEffectTravel(
  ReadendarBackgroundEffect effect,
  double extent,
) => switch (effect) {
  ReadendarBackgroundEffect.stormbound => Offset(0, extent),
  ReadendarBackgroundEffect.neonMoon => Offset(extent, 0),
  _ => Offset.zero,
};

Path _premiumVelarisRidgePath(Size size) => Path()
  ..moveTo(-size.width * 0.08, size.height * 0.98)
  ..lineTo(size.width * 0.09, size.height * 0.78)
  ..lineTo(size.width * 0.2, size.height * 0.72)
  ..lineTo(size.width * 0.32, size.height * 0.78)
  ..lineTo(size.width * 0.5, size.height * 0.4)
  ..lineTo(size.width * 0.63, size.height * 0.68)
  ..lineTo(size.width * 0.76, size.height * 0.56)
  ..lineTo(size.width * 1.08, size.height * 0.88);

double _premiumVelarisRidgeTravel(double cycle, double phaseOffset) =>
    0.5 - 0.5 * math.cos((cycle + phaseOffset) * math.pi * 2);

@visibleForTesting
Offset premiumVelarisRidgeGlintHead(
  Size size,
  double cycle, {
  double phaseOffset = 0,
}) {
  final metric = _premiumVelarisRidgePath(size).computeMetrics().first;
  final distance =
      _premiumVelarisRidgeTravel(cycle, phaseOffset) * metric.length;
  return metric.getTangentForOffset(distance)?.position ?? Offset.zero;
}

Path _premiumVelarisRidgeGlintPath(
  Size size,
  double cycle, {
  required double phaseOffset,
  required double length,
}) {
  final metric = _premiumVelarisRidgePath(size).computeMetrics().first;
  final end = _premiumVelarisRidgeTravel(cycle, phaseOffset) * metric.length;
  return metric.extractPath(math.max(0, end - length), end);
}

/// Paints the selected theme's app canvas behind the navigator.
class ReadendarThemeBackground extends StatelessWidget {
  const ReadendarThemeBackground({
    required this.child,
    this.animateEffects = true,
    super.key,
  });

  final Widget child;
  final bool animateEffects;

  @override
  Widget build(BuildContext context) {
    final treatment = context.readendarTheme.background;
    if (animateEffects && treatment.effect != ReadendarBackgroundEffect.none) {
      return _PremiumThemeBackground(treatment: treatment, child: child);
    }
    return _StaticThemeBackground(treatment: treatment, child: child);
  }
}

class _StaticThemeBackground extends StatelessWidget {
  const _StaticThemeBackground({required this.treatment, required this.child});

  final ReadendarBackgroundTreatment treatment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = treatment.colors;
    final gradient = switch (treatment.kind) {
      ReadendarBackgroundKind.solid => null,
      ReadendarBackgroundKind.linear => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      ),
      ReadendarBackgroundKind.radial => RadialGradient(
        center: const Alignment(0.45, -0.65),
        radius: 1.35,
        colors: colors,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.first, gradient: gradient),
      child: treatment.grainOpacity <= 0
          ? child
          : RepaintBoundary(
              child: CustomPaint(
                painter: _ThemeGrainPainter(
                  opacity: treatment.grainOpacity,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
                child: child,
              ),
            ),
    );
  }
}

class _PremiumThemeBackground extends StatefulWidget {
  const _PremiumThemeBackground({
    required this.treatment,
    required this.child,
  });

  final ReadendarBackgroundTreatment treatment;
  final Widget child;

  @override
  State<_PremiumThemeBackground> createState() =>
      _PremiumThemeBackgroundState();
}

class _PremiumThemeBackgroundState extends State<_PremiumThemeBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.maybeOf(context);
    final reduceMotion =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false) ||
        !TickerMode.valuesOf(context).enabled;
    if (reduceMotion) {
      _controller
        ..stop()
        ..value =
            widget.treatment.effect == ReadendarBackgroundEffect.stormbound
            ? 0
            : 0.18;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final treatment = widget.treatment;
    final colors = treatment.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.last),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            key: const Key('premium-theme-effect'),
            child: AnimatedBuilder(
              key: const Key('premium-theme-animation'),
              animation: _controller,
              builder: (context, _) => CustomPaint(
                key: Key('premium-theme-painter-${treatment.effect.name}'),
                isComplex: true,
                willChange: true,
                painter: _PremiumAtmospherePainter(
                  progress: _controller.value,
                  colors: colors,
                  dark: dark,
                  effect: treatment.effect,
                ),
              ),
            ),
          ),
          if (treatment.grainOpacity > 0)
            IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  isComplex: true,
                  painter: _ThemeGrainPainter(
                    opacity: treatment.grainOpacity,
                    dark: dark,
                  ),
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _PremiumAtmospherePainter extends CustomPainter {
  const _PremiumAtmospherePainter({
    required this.progress,
    required this.colors,
    required this.dark,
    required this.effect,
  });

  final double progress;
  final List<Color> colors;
  final bool dark;
  final ReadendarBackgroundEffect effect;

  @override
  void paint(Canvas canvas, Size size) {
    switch (effect) {
      case ReadendarBackgroundEffect.none:
        _paintBase(canvas, size, colors.first, colors.last);
      case ReadendarBackgroundEffect.ethereal:
        _paintEthereal(canvas, size);
      case ReadendarBackgroundEffect.stormbound:
        _paintStormbound(canvas, size);
      case ReadendarBackgroundEffect.evercourt:
        _paintVelaris(canvas, size);
      case ReadendarBackgroundEffect.neonMoon:
        _paintNeonMoon(canvas, size);
      case ReadendarBackgroundEffect.trail:
        _paintTrail(canvas, size);
      case ReadendarBackgroundEffect.serpents:
        _paintSerpents(canvas, size);
      case ReadendarBackgroundEffect.thornCrown:
        _paintThornCrown(canvas, size);
      case ReadendarBackgroundEffect.iridescent:
        _paintIridescent(canvas, size);
      case ReadendarBackgroundEffect.lastLight:
        _paintLastLight(canvas, size);
    }
  }

  void _paintBase(Canvas canvas, Size size, Color start, Color end) {
    final bounds = Offset.zero & size;
    final base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [start, end],
      ).createShader(bounds);
    canvas.drawRect(bounds, base);
  }

  void _paintEthereal(Canvas canvas, Size size) {
    _paintBase(canvas, size, colors.first, colors.last);

    final phase = progress * math.pi * 2;
    for (var index = 0; index < math.min(4, colors.length); index++) {
      final orbit = phase + index * math.pi * 0.63;
      final center = Offset(
        size.width * (0.18 + index * 0.22) +
            math.sin(orbit) * size.width * 0.12,
        size.height * (0.22 + (index.isEven ? 0.12 : 0.48)) +
            math.cos(orbit * 0.82) * size.height * 0.16,
      );
      final radius = math.max(size.width, size.height) * (0.42 + index * 0.035);
      final color = colors[index].withValues(alpha: dark ? 0.58 : 0.72);
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, glow);
    }

    final starPaint = Paint();
    final random = math.Random(9441);
    for (var index = 0; index < 42; index++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final twinkle =
          0.22 +
          0.78 *
              ((math.sin(phase * (0.7 + (index % 5) * 0.12) + index * 1.73) +
                      1) /
                  2);
      starPaint.color = Colors.white.withValues(
        alpha: (dark ? 0.5 : 0.32) * twinkle,
      );
      final radius = 0.35 + twinkle * (index % 7 == 0 ? 1.35 : 0.8);
      canvas.drawCircle(point, radius, starPaint);
      if (index % 11 == 0 && twinkle > 0.76) {
        final flare = radius * 2.5;
        starPaint.strokeWidth = 0.55;
        canvas.drawLine(
          Offset(point.dx - flare, point.dy),
          Offset(point.dx + flare, point.dy),
          starPaint,
        );
        canvas.drawLine(
          Offset(point.dx, point.dy - flare),
          Offset(point.dx, point.dy + flare),
          starPaint,
        );
      }
    }
    _paintShootingStar(canvas, size, progress: progress, lane: 0.16);
    _paintShootingStar(
      canvas,
      size,
      progress: (progress + 0.36) % 1,
      lane: 0.58,
    );
    _paintShootingStar(
      canvas,
      size,
      progress: (progress + 0.69) % 1,
      lane: 0.34,
    );
  }

  void _paintStormbound(Canvas canvas, Size size) {
    _paintBase(canvas, size, colors.first, colors.last);
    final phase = progress * math.pi * 2;
    final longest = math.max(size.width, size.height);

    // Two opposing pressure fronts move independently so the sky never reads
    // as a static gradient.
    for (var index = 0; index < 9; index++) {
      final depth = 0.72 + (index % 3) * 0.17;
      final center = Offset(
        size.width * (-0.08 + (index % 5) * 0.27) +
            math.sin(phase * (index.isEven ? 1 : 2) + index * 1.7) *
                size.width *
                0.12,
        size.height * (0.08 + (index ~/ 3) * 0.27) +
            math.cos(phase * (1 + index % 3) + index) * size.height * 0.07,
      );
      final radius = longest * (0.3 + (index % 4) * 0.045);
      final cloudColor = index.isEven
          ? colors[index % colors.length]
          : _shiftHue(colors[(index + 1) % colors.length], -16);
      final cloud = Paint()
        ..shader = RadialGradient(
          colors: [
            cloudColor.withValues(
              alpha: (dark ? 0.34 : 0.43) / depth,
            ),
            cloudColor.withValues(alpha: (dark ? 0.13 : 0.18) / depth),
            Colors.transparent,
          ],
          stops: const [0, 0.48, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, cloud);
    }

    // Dense vertical rain gives continuous motion between lightning events.
    final rainRandom = math.Random(9184);
    for (var index = 0; index < 48; index++) {
      final lane = rainRandom.nextDouble();
      final fall =
          (rainRandom.nextDouble() + progress * (2.2 + index % 4 * 0.16)) % 1;
      final start = Offset(lane * size.width, fall * size.height);
      final length = size.height * (0.018 + (index % 5) * 0.004);
      canvas.drawLine(
        start,
        start +
            premiumThemeEffectTravel(
              ReadendarBackgroundEffect.stormbound,
              length,
            ),
        Paint()
          ..color = Colors.white.withValues(
            alpha: (dark ? 0.18 : 0.13) + (index % 7 == 0 ? 0.08 : 0),
          )
          ..strokeWidth = index % 7 == 0 ? 1 : 0.55
          ..strokeCap = StrokeCap.round,
      );
    }

    // Several branched bolts fire across the loop, with a secondary snap in
    // each burst. This is intentionally much more legible than the old single
    // hairline that appeared for only a few frames.
    final bolts = [
      (
        start: Offset(size.width * 0.2, -8),
        end: Offset(size.width * 0.38, size.height * 0.58),
        pulse: _stormFlash(0.03),
        seed: 41,
      ),
      (
        start: Offset(size.width * 0.76, -8),
        end: Offset(size.width * 0.58, size.height * 0.66),
        pulse: _stormFlash(0.36),
        seed: 83,
      ),
      (
        start: Offset(size.width * 0.48, size.height * 0.03),
        end: Offset(size.width * 0.82, size.height * 0.5),
        pulse: _stormFlash(0.69),
        seed: 127,
      ),
    ];
    var skyFlash = 0.0;
    for (final bolt in bolts) {
      skyFlash = math.max(skyFlash, bolt.pulse);
      if (bolt.pulse > 0.01) {
        _paintLightning(
          canvas,
          size,
          start: bolt.start,
          end: bolt.end,
          intensity: bolt.pulse,
          seed: bolt.seed,
        );
      }
    }
    if (skyFlash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Colors.white.withValues(
            alpha: (dark ? 0.11 : 0.07) * skyFlash,
          ),
      );
    }

    // A distant, abstract wing shadow crosses beneath the storm deck.
    final wingTravel = (progress * 1.7 + 0.18) % 1;
    final wingCenter = Offset(
      size.width * (-0.18 + wingTravel * 1.36),
      size.height * (0.27 + math.sin(phase * 1.7) * 0.06),
    );
    final wingSpan = math.min(size.width, size.height) * 0.2;
    final wings = Path()
      ..moveTo(wingCenter.dx, wingCenter.dy)
      ..quadraticBezierTo(
        wingCenter.dx - wingSpan * 0.55,
        wingCenter.dy - wingSpan * 0.28,
        wingCenter.dx - wingSpan,
        wingCenter.dy + wingSpan * 0.06,
      )
      ..quadraticBezierTo(
        wingCenter.dx - wingSpan * 0.45,
        wingCenter.dy - wingSpan * 0.02,
        wingCenter.dx,
        wingCenter.dy + wingSpan * 0.16,
      )
      ..quadraticBezierTo(
        wingCenter.dx + wingSpan * 0.45,
        wingCenter.dy - wingSpan * 0.02,
        wingCenter.dx + wingSpan,
        wingCenter.dy + wingSpan * 0.06,
      )
      ..quadraticBezierTo(
        wingCenter.dx + wingSpan * 0.55,
        wingCenter.dy - wingSpan * 0.28,
        wingCenter.dx,
        wingCenter.dy,
      )
      ..close();
    canvas.drawPath(
      wings,
      Paint()..color = Colors.black.withValues(alpha: dark ? 0.11 : 0.07),
    );
  }

  double _stormFlash(double offset) {
    final local = ((progress + offset) * 4.4) % 1;
    if (local < 0.1) {
      return math.sin(math.pi * local / 0.1);
    }
    if (local >= 0.14 && local < 0.2) {
      return math.sin(math.pi * (local - 0.14) / 0.06) * 0.62;
    }
    return 0;
  }

  void _paintLightning(
    Canvas canvas,
    Size size, {
    required Offset start,
    required Offset end,
    required double intensity,
    required int seed,
  }) {
    final points = _lightningPoints(
      start,
      end,
      seed: seed,
      segments: 12,
      lateral: math.min(
        size.width * 0.034,
        start.dx - end.dx == 0
            ? size.width * 0.034
            : (end - start).distance * 0.055,
      ),
    );
    final path = _polyline(points);
    final violet = _spectral(268, (dark ? 0.72 : 0.5) * intensity);
    canvas.drawPath(
      path,
      Paint()
        ..color = violet
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 * intensity + 1.5
        ..strokeCap = StrokeCap.butt
        ..strokeJoin = StrokeJoin.bevel
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(
          alpha: (dark ? 0.96 : 0.82) * intensity,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 + intensity * 1.35
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.bevel,
    );

    for (final branchIndex in [3, 6, 9]) {
      final root = points[branchIndex];
      final direction = branchIndex.isEven ? 1.0 : -1.0;
      final branchEnd =
          root +
          Offset(
            size.width * (0.045 + branchIndex * 0.002) * direction,
            size.height * (0.105 + branchIndex * 0.004),
          );
      final branchPoints = _lightningPoints(
        root,
        branchEnd,
        seed: seed + branchIndex * 31,
        segments: 5,
        lateral: size.width * 0.012,
      );
      final branch = _polyline(branchPoints);
      canvas.drawPath(
        branch,
        Paint()
          ..color = violet.withValues(alpha: 0.62 * intensity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * intensity + 0.5
          ..strokeCap = StrokeCap.butt
          ..strokeJoin = StrokeJoin.bevel
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        branch,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.78 * intensity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.65 + intensity * 0.45
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.bevel,
      );
    }
  }

  List<Offset> _lightningPoints(
    Offset start,
    Offset end, {
    required int seed,
    required int segments,
    required double lateral,
  }) {
    final random = math.Random(seed);
    return <Offset>[
      start,
      for (var index = 1; index < segments; index++)
        Offset(
          start.dx +
              (end.dx - start.dx) * (index / segments) +
              (random.nextDouble() * 2 - 1) *
                  lateral *
                  math.sin(math.pi * index / segments),
          start.dy + (end.dy - start.dy) * (index / segments),
        ),
      end,
    ];
  }

  Path _polyline(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  void _paintVelaris(Canvas canvas, Size size) {
    _paintBase(canvas, size, colors.first, colors.last);
    final phase = progress * math.pi * 2;
    final unit = math.min(size.width, size.height);

    final summit = Offset(size.width * 0.5, size.height * 0.4);
    final holyStars = <Offset>[
      Offset(size.width * 0.5, size.height * 0.23),
      Offset(size.width * 0.4, size.height * 0.31),
      Offset(size.width * 0.6, size.height * 0.31),
    ];

    _paintGlow(
      canvas,
      Offset(size.width * 0.5, size.height * 0.2),
      unit * 0.48,
      _spectral(264, dark ? 0.19 : 0.11),
    );
    final rearMountain = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.86)
      ..lineTo(size.width * 0.16, size.height * 0.62)
      ..lineTo(size.width * 0.3, size.height * 0.74)
      ..lineTo(size.width * 0.42, size.height * 0.58)
      ..lineTo(size.width * 0.55, size.height * 0.72)
      ..lineTo(size.width * 0.75, size.height * 0.54)
      ..lineTo(size.width * 1.08, size.height * 0.84)
      ..lineTo(size.width * 1.08, size.height * 1.08)
      ..lineTo(-size.width * 0.08, size.height * 1.08)
      ..close();
    canvas.drawPath(
      rearMountain,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _spectral(251, dark ? 0.28 : 0.15),
            colors.last.withValues(alpha: dark ? 0.72 : 0.42),
          ],
        ).createShader(rearMountain.getBounds()),
    );

    final mountain = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.98)
      ..lineTo(size.width * 0.09, size.height * 0.78)
      ..lineTo(size.width * 0.2, size.height * 0.72)
      ..lineTo(size.width * 0.32, size.height * 0.78)
      ..lineTo(summit.dx, summit.dy)
      ..lineTo(size.width * 0.63, size.height * 0.68)
      ..lineTo(size.width * 0.76, size.height * 0.56)
      ..lineTo(size.width * 1.08, size.height * 0.88)
      ..lineTo(size.width * 1.08, size.height * 1.08)
      ..lineTo(-size.width * 0.08, size.height * 1.08)
      ..close();
    canvas.drawPath(
      mountain,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _spectral(264, dark ? 0.5 : 0.24),
            colors.last.withValues(alpha: dark ? 0.96 : 0.7),
            _spectral(322, dark ? 0.28 : 0.14),
          ],
          stops: const [0, 0.54, 1],
        ).createShader(mountain.getBounds()),
    );

    final leftFacet = Path()
      ..moveTo(size.width * 0.09, size.height * 0.78)
      ..lineTo(summit.dx, summit.dy)
      ..lineTo(size.width * 0.47, size.height * 1.08)
      ..lineTo(-size.width * 0.08, size.height * 1.08)
      ..close();
    canvas.drawPath(
      leftFacet,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomLeft,
          colors: [
            _spectral(251, dark ? 0.44 : 0.2),
            Colors.transparent,
          ],
        ).createShader(leftFacet.getBounds()),
    );
    final rightFacet = Path()
      ..moveTo(summit.dx, summit.dy)
      ..lineTo(size.width * 0.63, size.height * 0.68)
      ..lineTo(size.width * 0.55, size.height * 1.08)
      ..lineTo(size.width * 0.47, size.height * 1.08)
      ..close();
    canvas.drawPath(
      rightFacet,
      Paint()..color = _spectral(322, dark ? 0.14 : 0.09),
    );

    final ridge = _premiumVelarisRidgePath(size);
    canvas.drawPath(
      ridge,
      Paint()
        ..color = Colors.white.withValues(alpha: dark ? 0.4 : 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..strokeJoin = StrokeJoin.bevel,
    );
    for (var index = 0; index < 4; index++) {
      final glint = _premiumVelarisRidgeGlintPath(
        size,
        progress,
        phaseOffset: index / 4,
        length: unit * (index.isEven ? 0.12 : 0.08),
      );
      canvas.drawPath(
        glint,
        Paint()
          ..color = (index.isEven ? _spectral(48, 1) : Colors.white).withValues(
            alpha: dark ? 0.8 : 0.68,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = index.isEven ? 2 : 1.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    for (var index = 0; index < holyStars.length; index++) {
      final pulse = 0.88 + math.sin(phase * 0.42 + index * 1.8) * 0.1;
      final center = holyStars[index];
      final radius = unit * (index == 0 ? 0.029 : 0.024) * pulse;
      _paintGlow(
        canvas,
        center,
        radius * 4.8,
        _spectral(index == 0 ? 48 : 264, dark ? 0.32 : 0.2),
      );
      _paintVelarisStar(
        canvas,
        center,
        radius,
        (index == 0 ? _spectral(48, 1) : Colors.white).withValues(
          alpha: dark ? 0.96 : 0.88,
        ),
      );
    }

    final veil = Rect.fromLTWH(
      0,
      size.height * 0.82,
      size.width,
      size.height * 0.18,
    );
    canvas.drawRect(
      veil,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, colors.last.withValues(alpha: 0.5)],
        ).createShader(veil),
    );
  }

  void _paintVelarisStar(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final star = Path();
    for (var index = 0; index < 16; index++) {
      final angle = -math.pi / 2 + index * math.pi / 8;
      final pointRadius = index.isEven
          ? radius * (index % 4 == 0 ? 1.85 : 1.05)
          : radius * 0.34;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * pointRadius;
      if (index == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = color);
  }

  void _paintNeonMoon(Canvas canvas, Size size) {
    _paintBase(canvas, size, colors.first, colors.last);
    final phase = progress * math.pi * 2;
    final unit = math.min(size.width, size.height);
    final moonCenter = Offset(size.width * 0.77, size.height * 0.17);
    final moonRadius = math.min(size.width, size.height) * 0.13;
    _paintGlow(
      canvas,
      moonCenter,
      moonRadius * 2.7,
      _spectral(188, dark ? 0.2 : 0.14),
    );
    canvas.drawCircle(
      moonCenter,
      moonRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = _spectral(188, dark ? 0.72 : 0.5),
    );
    canvas.drawCircle(
      moonCenter + Offset(moonRadius * 0.38, -moonRadius * 0.12),
      moonRadius * 0.9,
      Paint()..color = colors.last.withValues(alpha: dark ? 0.82 : 0.66),
    );

    // A pulsing gate and stepped skyline anchor this in a magical metropolis,
    // not the faceted-glass language used by Prism.
    final gate = Offset(size.width * 0.23, size.height * 0.43);
    final gatePulse = (math.sin(phase * 2) + 1) / 2;
    _paintGlow(
      canvas,
      gate,
      unit * (0.16 + gatePulse * 0.025),
      _spectral(326, dark ? 0.22 : 0.14),
    );
    for (var ring = 0; ring < 3; ring++) {
      canvas.drawCircle(
        gate,
        unit * (0.065 + ring * 0.025 + gatePulse * 0.006),
        Paint()
          ..color = _spectral(
            ring.isEven ? 326 : 188,
            (dark ? 0.7 : 0.46) - ring * 0.12,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring == 0 ? 2.4 : 1,
      );
    }

    final skylinePaint = Paint()..color = colors.last.withValues(alpha: 0.5);
    for (var index = 0; index < 13; index++) {
      final left = size.width * (index / 13);
      final width = size.width * (0.055 + (index % 3) * 0.012);
      final top = size.height * (0.35 + ((index * 37) % 17) / 85);
      final building = Rect.fromLTRB(
        left,
        top,
        left + width,
        size.height * 0.74,
      );
      canvas.drawRect(building, skylinePaint);
      for (var window = 0; window < 3; window++) {
        final lit = (index + window + (progress * 8).floor()).isEven;
        if (!lit) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            left + width * 0.22,
            top + 8 + window * 13,
            width * 0.16,
            4,
          ),
          Paint()
            ..color = _spectral(
              index.isEven ? 188 : 326,
              dark ? 0.58 : 0.36,
            ),
        );
      }
    }

    // Cyan and magenta light traffic replaces rain with a motion language tied
    // to the neon skyline. Trails stay horizontal and below the moon so they
    // read as city energy without adding noise over foreground content.
    final trailRandom = math.Random(3319);
    for (var index = 0; index < 18; index++) {
      final travel =
          (trailRandom.nextDouble() + progress * (0.42 + index % 4 * 0.05)) % 1;
      final start = Offset(
        size.width * (-0.16 + travel * 1.12),
        size.height * (0.38 + trailRandom.nextDouble() * 0.34),
      );
      final delta = premiumThemeEffectTravel(
        ReadendarBackgroundEffect.neonMoon,
        unit * (0.055 + (index % 5) * 0.012),
      );
      final color = index.isEven
          ? _spectral(188, dark ? 0.42 : 0.28)
          : _spectral(326, dark ? 0.48 : 0.3);
      canvas.drawLine(
        start,
        start + delta,
        Paint()
          ..color = color.withValues(alpha: color.a * 0.22)
          ..strokeWidth = index % 5 == 0 ? 5 : 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        start,
        start + delta,
        Paint()
          ..color = color
          ..strokeWidth = index % 5 == 0 ? 1.3 : 0.75
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var index = 0; index < 18; index++) {
      final y = size.height * (0.69 + index * 0.018);
      final width = size.width * (0.035 + ((index * 7) % 6) * 0.018);
      final x =
          size.width * (0.1 + 0.8 * ((math.sin(index * 1.9 + phase) + 1) / 2));
      canvas.drawLine(
        Offset(x - width, y),
        Offset(x + width, y),
        Paint()
          ..color = _spectral(
            index.isEven ? 188 : 326,
            dark ? 0.34 : 0.23,
          )
          ..strokeWidth = index.isEven ? 1.8 : 0.9
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintTrail(Canvas canvas, Size size) {
    _paintBase(canvas, size, colors.first, colors.last);
    final phase = progress * math.pi * 2;
    final unit = math.min(size.width, size.height);
    for (var index = 0; index < 30; index++) {
      final route = index % 3;
      final travel = (index / 30 + progress * (0.42 + route * 0.05)) % 1;
      final point = Offset(
        size.width * (-0.08 + travel * 1.16),
        size.height *
            (0.94 -
                travel * (0.52 + route * 0.12) +
                math.sin(travel * math.pi * 2 + route + phase * 0.12) * 0.045),
      );
      _paintCaninePaw(
        canvas,
        point,
        unit * (0.014 + route * 0.0025),
        _spectral(route.isEven ? 32 : 188, dark ? 0.54 : 0.38),
      );
    }
  }

  void _paintSerpents(Canvas canvas, Size size) {
    _paintBase(canvas, size, colors.first, colors.last);
    final phase = progress * math.pi * 2;
    final unit = math.min(size.width, size.height);
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()..color = Colors.black.withValues(alpha: dark ? 0.2 : 0.055),
    );

    // A moving scale lattice gives the black-lacquer field its own material.
    final scale = math.max(14, unit * 0.13).toDouble();
    for (var row = -1; row < (size.height / scale).ceil() + 1; row++) {
      for (
        var column = -1;
        column < (size.width / scale).ceil() + 1;
        column++
      ) {
        final center = Offset(
          column * scale +
              (row.isOdd ? scale / 2 : 0) +
              math.sin(phase + row) * scale * 0.12,
          row * scale + progress * scale,
        );
        canvas.drawArc(
          Rect.fromCenter(
            center: center,
            width: scale,
            height: scale * 0.72,
          ),
          0,
          math.pi,
          false,
          Paint()
            ..color = _spectral(
              (row + column).isEven ? 146 : 45,
              dark ? 0.14 : 0.1,
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.65,
        );
      }
    }

    for (var serpent = 0; serpent < 4; serpent++) {
      final y = size.height * (0.18 + serpent * 0.2);
      final amplitude = unit * (0.095 + serpent * 0.012);
      final path = Path()..moveTo(-unit * 0.14, y);
      for (var step = 1; step <= 48; step++) {
        final t = step / 48;
        final x = size.width * (t * 1.2 - 0.1);
        final wave = math.sin(
          t * math.pi * (3.2 + serpent * 0.45) +
              phase * (serpent.isEven ? 1 : -0.8) +
              serpent,
        );
        path.lineTo(x, y + wave * amplitude);
      }
      final hue = serpent.isEven ? 146.0 : 45.0;
      canvas.drawPath(
        path,
        Paint()
          ..color = _spectral(hue, dark ? 0.13 : 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * (0.045 + serpent * 0.004)
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.028),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _spectral(146, dark ? 0.78 : 0.52),
              _spectral(45, dark ? 0.62 : 0.44),
              _spectral(166, dark ? 0.72 : 0.48),
            ],
          ).createShader(bounds)
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * (0.013 + serpent * 0.0015)
          ..strokeCap = StrokeCap.round,
      );
    }

    final ringCenter = Offset(size.width * 0.78, size.height * 0.2);
    for (var ring = 0; ring < 4; ring++) {
      canvas.drawArc(
        Rect.fromCircle(
          center: ringCenter,
          radius: unit * (0.07 + ring * 0.04),
        ),
        phase * (ring.isEven ? 0.5 : -0.4) + ring,
        math.pi * 1.28,
        false,
        Paint()
          ..color = _spectral(ring.isEven ? 45 : 146, dark ? 0.4 : 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _paintCaninePaw(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - radius, center.dy + radius * 0.9)
        ..quadraticBezierTo(
          center.dx,
          center.dy - radius * 0.05,
          center.dx + radius,
          center.dy + radius * 0.9,
        )
        ..quadraticBezierTo(
          center.dx + radius * 0.7,
          center.dy + radius * 1.65,
          center.dx,
          center.dy + radius * 1.55,
        )
        ..quadraticBezierTo(
          center.dx - radius * 0.7,
          center.dy + radius * 1.65,
          center.dx - radius,
          center.dy + radius * 0.9,
        )
        ..close(),
      paint,
    );
    for (var toe = 0; toe < 4; toe++) {
      final angle = math.pi * (0.08 + toe * 0.28);
      final toeCenter =
          center + Offset(math.cos(angle), -math.sin(angle)) * radius * 1.35;
      canvas.drawOval(
        Rect.fromCenter(
          center: toeCenter,
          width: radius * 0.66,
          height: radius * 0.82,
        ),
        paint,
      );
      final clawStart = toeCenter + Offset(0, -radius * 0.5);
      canvas.drawLine(
        clawStart,
        clawStart + Offset(0, -radius * 0.32),
        Paint()
          ..color = color.withValues(alpha: color.a * 0.72)
          ..strokeWidth = math.max(0.55, radius * 0.1)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintThornCrown(Canvas canvas, Size size) {
    _paintBase(canvas, size, colors.first, colors.last);
    final phase = progress * math.pi * 2;
    final unit = math.min(size.width, size.height);

    // Moving pools of forest light keep the full canvas alive behind the vines.
    for (var index = 0; index < 6; index++) {
      final center = Offset(
        size.width * (0.08 + index * 0.18) +
            math.sin(phase * (1 + index % 2) + index) * unit * 0.08,
        size.height * (0.18 + (index % 3) * 0.28),
      );
      _paintGlow(
        canvas,
        center,
        unit * (0.24 + index % 2 * 0.05),
        _spectral(index.isEven ? 108 : 326, dark ? 0.14 : 0.11),
      );
    }

    _paintVine(
      canvas,
      size,
      phase: phase,
      start: Offset(-unit * 0.08, size.height * 0.88),
      end: Offset(size.width * 1.08, size.height * 0.64),
      bend: -0.2,
      seed: 17,
    );
    _paintVine(
      canvas,
      size,
      phase: phase + 1.9,
      start: Offset(size.width * 0.04, size.height * 1.05),
      end: Offset(size.width * 0.2, -unit * 0.08),
      bend: 0.24,
      seed: 31,
    );
    _paintVine(
      canvas,
      size,
      phase: phase + 3.7,
      start: Offset(size.width * 0.98, size.height * 1.06),
      end: Offset(size.width * 0.82, -unit * 0.1),
      bend: -0.22,
      seed: 53,
    );

    final mothRandom = math.Random(5981);
    for (var index = 0; index < 16; index++) {
      final travel =
          (mothRandom.nextDouble() + progress * (0.12 + index % 4 * 0.025)) % 1;
      final point = Offset(
        (mothRandom.nextDouble() + math.sin(phase + index) * 0.08) * size.width,
        (1 - travel) * size.height,
      );
      final wing = unit * (0.008 + index % 3 * 0.003);
      final open = 0.45 + 0.55 * ((math.sin(phase * 3 + index) + 1) / 2);
      final mothPaint = Paint()
        ..color = index % 5 == 0
            ? _spectral(326, dark ? 0.42 : 0.32)
            : _spectral(48, dark ? 0.38 : 0.3);
      canvas.drawOval(
        Rect.fromCenter(
          center: point + Offset(-wing * 0.65, 0),
          width: wing * open,
          height: wing * 1.4,
        ),
        mothPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: point + Offset(wing * 0.65, 0),
          width: wing * open,
          height: wing * 1.4,
        ),
        mothPaint,
      );
    }
  }

  void _paintIridescent(Canvas canvas, Size size) {
    _paintBase(canvas, size, colors.first, colors.last);
    final phase = progress * math.pi * 2;
    final bounds = Offset.zero & size;
    final longest = math.max(size.width, size.height);

    // Graphite glaze: even the light palette reads as smoked dichroic glass,
    // while retaining the surrounding light-theme semantic surfaces.
    canvas.drawRect(
      bounds,
      Paint()..color = Colors.black.withValues(alpha: dark ? 0.3 : 0.1),
    );

    // A rotating fan of translucent facets creates structural color. Each
    // polygon changes hue with angle, unlike Neon's fixed cyan/magenta lights.
    final facetCenter = Offset(
      size.width * (0.5 + math.sin(phase) * 0.08),
      size.height * (0.48 + math.cos(phase) * 0.06),
    );
    for (var index = 0; index < 18; index++) {
      final angleA = index * math.pi * 2 / 18 + phase;
      final angleB = (index + 1) * math.pi * 2 / 18 + phase;
      final radiusA = longest * (0.58 + index % 3 * 0.1);
      final radiusB = longest * (0.58 + (index + 1) % 3 * 0.1);
      final path = Path()
        ..moveTo(facetCenter.dx, facetCenter.dy)
        ..lineTo(
          facetCenter.dx + math.cos(angleA) * radiusA,
          facetCenter.dy + math.sin(angleA) * radiusA,
        )
        ..lineTo(
          facetCenter.dx + math.cos(angleB) * radiusB,
          facetCenter.dy + math.sin(angleB) * radiusB,
        )
        ..close();
      final hue = (index * 43 + progress * 360) % 360;
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
              _spectral(hue, dark ? 0.13 : 0.15),
              Colors.white.withValues(alpha: dark ? 0.025 : 0.08),
            ],
          ).createShader(bounds),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _spectral(hue + 36, dark ? 0.34 : 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = index % 4 == 0 ? 1.35 : 0.55,
      );
    }

    // Multiple moving caustics cover the whole canvas with visible spectral
    // travel instead of the previous four faint rectangular strips.
    for (var index = 0; index < 7; index++) {
      final y = size.height * (0.08 + index * 0.145);
      final path = Path()
        ..moveTo(-size.width * 0.2, y)
        ..cubicTo(
          size.width * 0.25,
          y + math.sin(phase * (1 + index % 2) + index) * size.height * 0.13,
          size.width * 0.72,
          y +
              math.cos(phase * (2 + index % 2) + index * 0.8) *
                  size.height *
                  0.12,
          size.width * 1.2,
          y + math.sin(phase * (1 + index % 3) + index) * size.height * 0.08,
        );
      final hue = (progress * 360 + index * 51) % 360;
      canvas.drawPath(
        path,
        Paint()
          ..color = _spectral(hue, dark ? 0.18 : 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = longest * 0.045
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, longest * 0.026),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              _spectral(hue - 34, 0),
              _spectral(hue, dark ? 0.62 : 0.48),
              _spectral(hue + 76, dark ? 0.72 : 0.56),
              _spectral(hue + 130, 0),
            ],
          ).createShader(bounds)
          ..style = PaintingStyle.stroke
          ..strokeWidth = index.isEven ? 1.8 : 1.15
          ..strokeCap = StrokeCap.round,
      );
    }

    // Thin interference contours and triangular glints sell the coated-glass
    // surface at rest as well as in motion.
    final contourCenter = Offset(
      size.width * (0.62 + math.sin(phase) * 0.18),
      size.height * (0.38 + math.cos(phase) * 0.16),
    );
    for (var index = 0; index < 9; index++) {
      final radius = longest * (0.08 + index * 0.055);
      canvas.drawOval(
        Rect.fromCenter(
          center: contourCenter,
          width: radius * 2.2,
          height: radius * 0.9,
        ),
        Paint()
          ..color = _spectral(
            progress * 360 + index * 31,
            (dark ? 0.25 : 0.2) * (1 - index / 12),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.65,
      );
    }

    final fleckRandom = math.Random(4412);
    for (var index = 0; index < 28; index++) {
      final point = Offset(
        fleckRandom.nextDouble() * size.width,
        fleckRandom.nextDouble() * size.height,
      );
      final shimmer = (math.sin(phase * (1 + index % 4) + index) + 1) / 2;
      final radius = 1.2 + (index % 4) * 0.55;
      final triangle = Path()
        ..moveTo(point.dx, point.dy - radius)
        ..lineTo(point.dx + radius, point.dy + radius)
        ..lineTo(point.dx - radius, point.dy + radius * 0.55)
        ..close();
      canvas.drawPath(
        triangle,
        Paint()
          ..color = _spectral(
            progress * 360 + index * 47,
            (dark ? 0.28 : 0.24) * shimmer,
          ),
      );
    }

    final sweep = (progress * 1.35) % 1;
    final sweepRect = Rect.fromCenter(
      center: Offset(size.width * (-0.2 + sweep * 1.4), size.height * 0.48),
      width: size.width * 0.25,
      height: size.height * 1.6,
    );
    canvas.save();
    canvas.translate(sweepRect.center.dx, sweepRect.center.dy);
    canvas.rotate(-0.27);
    canvas.translate(-sweepRect.center.dx, -sweepRect.center.dy);
    canvas.drawRect(
      sweepRect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: dark ? 0.08 : 0.18),
            _spectral(progress * 360 + 120, dark ? 0.12 : 0.16),
            Colors.transparent,
          ],
        ).createShader(sweepRect),
    );
    canvas.restore();
  }

  void _paintVine(
    Canvas canvas,
    Size size, {
    required double phase,
    required Offset start,
    required Offset end,
    required double bend,
    required int seed,
  }) {
    final random = math.Random(seed);
    final unit = math.min(size.width, size.height);
    final points = <Offset>[];
    const segments = 18;
    for (var step = 0; step <= segments; step++) {
      final t = step / segments;
      final base = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      final normal = Offset(-(end.dy - start.dy), end.dx - start.dx);
      final normalLength = normal.distance;
      final sway =
          math.sin(t * math.pi * 3 + phase + seed) * unit * 0.035 +
          math.sin(t * math.pi) * unit * bend;
      points.add(base + normal / normalLength * sway);
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _spectral(112, dark ? 0.54 : 0.48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    for (var index = 2; index < points.length - 1; index += 2) {
      final point = points[index];
      final tangent = points[index + 1] - points[index - 1];
      final angle = math.atan2(tangent.dy, tangent.dx);
      final side = index.isEven ? 1.0 : -1.0;
      final leafLength = unit * (0.032 + random.nextDouble() * 0.018);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + side * 0.85 + math.sin(phase + index) * 0.08);
      canvas.drawOval(
        Rect.fromLTWH(0, -leafLength * 0.23, leafLength, leafLength * 0.46),
        Paint()..color = _spectral(96, dark ? 0.4 : 0.36),
      );
      final thorn = Path()
        ..moveTo(0, 0)
        ..lineTo(-leafLength * 0.3, -side * leafLength * 0.45)
        ..lineTo(leafLength * 0.08, -side * leafLength * 0.1)
        ..close();
      canvas.drawPath(
        thorn,
        Paint()..color = _spectral(326, dark ? 0.62 : 0.52),
      );
      if (index % 6 == 0) {
        final glint = (math.sin(phase * 2 + index) + 1) / 2;
        canvas.drawCircle(
          Offset(leafLength * 0.18, side * leafLength * 0.34),
          2.1 + glint,
          Paint()..color = _spectral(334, 0.4 + glint * 0.4),
        );
      }
      canvas.restore();
    }
  }

  void _paintLastLight(Canvas canvas, Size size) {
    _paintBase(canvas, size, colors.first, colors.last);
    final phase = progress * math.pi * 2;
    final unit = math.min(size.width, size.height);
    final star = Offset(size.width * 0.73, size.height * 0.22);
    final pulse = (math.sin(phase * 2) + 1) / 2;
    final haloRadius = unit * (0.23 + pulse * 0.025);
    _paintGlow(
      canvas,
      star,
      haloRadius * 1.8,
      _spectral(28, dark ? 0.3 : 0.22),
    );
    canvas.drawCircle(
      star,
      unit * 0.025,
      Paint()
        ..color = dark
            ? Colors.white.withValues(alpha: 0.88)
            : _spectral(34, 0.82),
    );

    final fieldRandom = math.Random(6142);
    for (var index = 0; index < 34; index++) {
      final parallax = (progress * (0.025 + index % 4 * 0.008)) % 1;
      final point = Offset(
        (fieldRandom.nextDouble() + parallax) % 1 * size.width,
        fieldRandom.nextDouble() * size.height,
      );
      final blink = (math.sin(phase * (1 + index % 3) + index) + 1) / 2;
      canvas.drawCircle(
        point,
        index % 9 == 0 ? 1.4 : 0.55,
        Paint()
          ..color = (dark ? Colors.white : _spectral(210, 1)).withValues(
            alpha: (dark ? 0.38 : 0.32) * (0.45 + blink * 0.55),
          ),
      );
    }

    for (var index = 0; index < 6; index++) {
      final radius = unit * (0.1 + index * 0.07);
      canvas.drawArc(
        Rect.fromCircle(center: star, radius: radius),
        phase * (index.isEven ? 1 : -1) + index,
        math.pi * (0.72 + index * 0.08),
        false,
        Paint()
          ..color = _spectral(
            index.isEven ? 24 : 205,
            dark ? 0.42 : 0.34,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = index == 0 ? 1.7 : 0.85
          ..strokeCap = StrokeCap.round,
      );
      final packetAngle = phase * (index.isEven ? 1 : -1) + index * 1.3;
      final packet =
          star + Offset(math.cos(packetAngle), math.sin(packetAngle)) * radius;
      canvas.drawCircle(
        packet,
        index.isEven ? 2.2 : 1.25,
        Paint()..color = _spectral(24, dark ? 0.78 : 0.64),
      );
    }

    // Rotating instrument sweep with a small abstract vessel marker.
    final scanAngle = phase;
    canvas.drawLine(
      star,
      star + Offset(math.cos(scanAngle), math.sin(scanAngle)) * unit * 0.42,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _spectral(24, dark ? 0.56 : 0.46),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: star, radius: unit * 0.42))
        ..strokeWidth = 1.2,
    );
    final vessel = Offset(
      size.width * (0.27 + math.sin(phase) * 0.035),
      size.height * (0.38 + math.cos(phase) * 0.025),
    );
    _paintGlow(
      canvas,
      vessel,
      unit * 0.09,
      _spectral(205, dark ? 0.18 : 0.14),
    );
    canvas.drawCircle(
      vessel,
      unit * 0.027,
      Paint()
        ..color = _spectral(205, dark ? 0.24 : 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      vessel,
      unit * 0.027,
      Paint()
        ..color = dark
            ? Colors.white.withValues(alpha: 0.55)
            : _spectral(205, 0.52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    canvas.drawLine(
      vessel - Offset(unit * 0.075, 0),
      vessel + Offset(unit * 0.075, 0),
      Paint()
        ..color = _spectral(24, dark ? 0.46 : 0.38)
        ..strokeWidth = 1.4,
    );

    // Instrument grid and a live waveform fill the quiet lower deck.
    for (var index = 0; index <= 8; index++) {
      final y = size.height * (0.6 + index * 0.045);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = _spectral(205, dark ? 0.1 : 0.085)
          ..strokeWidth = 0.6,
      );
    }
    for (var index = 0; index <= 12; index++) {
      final x = size.width * index / 12;
      canvas.drawLine(
        Offset(x, size.height * 0.58),
        Offset(x, size.height),
        Paint()
          ..color = _spectral(205, dark ? 0.08 : 0.07)
          ..strokeWidth = 0.5,
      );
    }
    final dataRandom = math.Random(2507);
    for (var index = 0; index < 26; index++) {
      final travel =
          (dataRandom.nextDouble() + progress * (0.48 + index % 4 * 0.08)) % 1;
      final point = Offset(
        travel * size.width,
        size.height * (0.61 + (index % 7) * 0.052),
      );
      final width = unit * (0.012 + index % 3 * 0.008);
      canvas.drawLine(
        point,
        point + Offset(width, 0),
        Paint()
          ..color = _spectral(
            index.isEven ? 24 : 205,
            dark ? 0.32 : 0.27,
          )
          ..strokeWidth = index % 5 == 0 ? 1.5 : 0.8
          ..strokeCap = StrokeCap.round,
      );
    }

    final telemetry = Path()..moveTo(0, size.height * 0.82);
    for (var step = 0; step <= 72; step++) {
      final x = size.width * step / 72;
      final carrier = math.sin(step * 0.7 + phase * 2) * 0.012;
      final signal = step % 13 < 3
          ? math.sin(step * 2.1 + phase * 4) * 0.045
          : 0.0;
      telemetry.lineTo(
        x,
        size.height * (0.82 - carrier - signal),
      );
    }
    canvas.drawPath(
      telemetry,
      Paint()
        ..color = _spectral(24, dark ? 0.66 : 0.52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintGlow(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  Color _shiftHue(Color color, double degrees) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withHue((hsl.hue + degrees) % 360)
        .withSaturation(math.max(0.18, hsl.saturation))
        .toColor();
  }

  Color _spectral(double hue, double alpha) => HSVColor.fromAHSV(
    alpha.clamp(0.0, 1.0),
    hue % 360,
    dark ? 0.78 : 0.68,
    dark ? 1 : 0.78,
  ).toColor();

  void _paintShootingStar(
    Canvas canvas,
    Size size, {
    required double progress,
    required double lane,
  }) {
    // A short part of the loop is visible, leaving spacious pauses between
    // streaks instead of turning the canvas into a persistent meteor shower.
    const visibleWindow = 0.16;
    if (progress > visibleWindow) return;
    final travel = Curves.easeOutCubic.transform(progress / visibleWindow);
    final intensity = math.sin(math.pi * progress / visibleWindow);
    final head = Offset(
      size.width * (-0.08 + travel * 1.16),
      size.height * (lane + travel * 0.38),
    );
    final tail = Offset(
      head.dx - size.width * 0.15,
      head.dy - size.height * 0.08,
    );
    final glow = Colors.white.withValues(
      alpha: (dark ? 0.88 : 0.68) * intensity,
    );
    final trail = Paint()
      ..strokeWidth = 1.15 + intensity * 0.75
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [glow.withValues(alpha: 0), glow],
      ).createShader(Rect.fromPoints(tail, head));
    canvas.drawLine(tail, head, trail);
    final headPaint = Paint()..color = glow;
    canvas.drawCircle(head, 1.2 + intensity * 1.15, headPaint);
  }

  @override
  bool shouldRepaint(covariant _PremiumAtmospherePainter oldDelegate) =>
      progress != oldDelegate.progress ||
      dark != oldDelegate.dark ||
      effect != oldDelegate.effect ||
      oldDelegate.colors != colors;
}

class _ThemeGrainPainter extends CustomPainter {
  const _ThemeGrainPainter({required this.opacity, required this.dark});

  final double opacity;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7319);
    final paint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: opacity)
      ..strokeWidth = 0.7;
    final count = math.max(80, (size.width * size.height / 2600).round());
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.35 + random.nextDouble() * 0.45,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThemeGrainPainter oldDelegate) =>
      opacity != oldDelegate.opacity || dark != oldDelegate.dark;
}
