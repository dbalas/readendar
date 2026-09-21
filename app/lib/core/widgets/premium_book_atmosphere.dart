import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';

/// Premium-only cinematic frame for book headers.
///
/// Cover colour extraction happens from Flutter's already-decoded image, on the
/// device, and is used only when the user enabled the cover-led atmosphere.
/// Nothing is uploaded or persisted. The background and foreground move at
/// different rates to create restrained depth while scrolling.
class PremiumBookAtmosphere extends StatefulWidget {
  const PremiumBookAtmosphere({
    required this.themeId,
    required this.coverUrl,
    required this.coverColorsEnabled,
    required this.scrollController,
    required this.child,
    this.progressFraction = 0,
    super.key,
  });

  final ReadendarThemeId themeId;
  final String coverUrl;
  final bool coverColorsEnabled;
  final ScrollController scrollController;
  final Widget child;

  /// Reading progress drives only the density of the theme artwork. It is
  /// clamped locally and never persisted by this widget.
  final double progressFraction;

  @override
  State<PremiumBookAtmosphere> createState() => _PremiumBookAtmosphereState();
}

class _PremiumBookAtmosphereState extends State<PremiumBookAtmosphere> {
  Color? _coverColor;
  String? _resolvedUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveCoverColor();
  }

  @override
  void didUpdateWidget(covariant PremiumBookAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl ||
        oldWidget.coverColorsEnabled != widget.coverColorsEnabled) {
      _resolveCoverColor();
    }
  }

  void _resolveCoverColor() {
    final url = widget.coverUrl.trim();
    if (!widget.coverColorsEnabled || url.isEmpty) {
      _resolvedUrl = null;
      _coverColor = null;
      return;
    }
    if (_resolvedUrl == url) return;
    _resolvedUrl = url;
    unawaited(() async {
      final color = await CoverPaletteExtractor.dominantColor(
        CachedNetworkImageProvider(url),
        createLocalImageConfiguration(context),
      );
      if (!mounted || _resolvedUrl != url) return;
      setState(() => _coverColor = color);
    }());
  }

  @override
  Widget build(BuildContext context) {
    final definition = ReadendarThemes.byId(widget.themeId);
    if (!definition.isPremium) return widget.child;
    final colors = context.colors;
    final treatment = definition.background(Theme.of(context).brightness);
    final identity = definition.identity.effect;
    final radius = BorderRadius.circular(definition.style.cardRadius);
    return ClipRRect(
      key: const Key('premiumBookAtmosphere'),
      borderRadius: radius,
      child: AnimatedBuilder(
        animation: widget.scrollController,
        builder: (context, _) {
          final offset = widget.scrollController.hasClients
              ? widget.scrollController.offset.clamp(0.0, 180.0)
              : 0.0;
          return Stack(
            children: [
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(0, -offset * 0.12),
                  child: Transform.scale(
                    scale: 1.16,
                    child: _CinematicBackdrop(
                      themeId: widget.themeId,
                      colors: treatment.colors,
                      coverUrl: widget.coverColorsEnabled
                          ? widget.coverUrl
                          : '',
                      coverColor: _coverColor,
                    ),
                  ),
                ),
              ),
              if (identity == ReadendarIdentityEffect.ethereal)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: const Key('etherealBookConstellation'),
                        painter: _EtherealBookConstellationPainter(
                          progress: widget.progressFraction.clamp(0.0, 1.0),
                          lineColor: colors.accent,
                          starColor: colors.accent2,
                        ),
                      ),
                    ),
                  ),
                ),
              if (identity != ReadendarIdentityEffect.none &&
                  identity != ReadendarIdentityEffect.ethereal)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        key: Key('premiumBookArtwork-${identity.name}'),
                        painter: _PremiumBookIdentityPainter(
                          identity: identity,
                          progress: widget.progressFraction.clamp(0.0, 1.0),
                          primary: colors.accent,
                          secondary: colors.accent2,
                        ),
                      ),
                    ),
                  ),
                ),
              if (identity != ReadendarIdentityEffect.none)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: Key(
                        identity == ReadendarIdentityEffect.ethereal
                            ? 'etherealBookHalo'
                            : 'premiumBookHalo-${identity.name}',
                      ),
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.55, -0.7),
                          radius: 0.95,
                          colors: [
                            colors.accent2.withValues(alpha: 0.16),
                            colors.accent.withValues(alpha: 0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.2),
                    ),
                    borderRadius: radius,
                  ),
                ),
              ),
              Transform.translate(
                key: const Key('premiumBookAtmosphereForeground'),
                offset: Offset(0, -offset * 0.025),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: widget.child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CinematicBackdrop extends StatelessWidget {
  const _CinematicBackdrop({
    required this.themeId,
    required this.colors,
    required this.coverUrl,
    required this.coverColor,
  });

  final ReadendarThemeId themeId;
  final List<Color> colors;
  final String coverUrl;
  final Color? coverColor;

  @override
  Widget build(BuildContext context) {
    final fallback = colors.length > 1 ? colors[1] : colors.first;
    final transformedCover = _themeCoverColor(
      themeId,
      coverColor,
      context.colors.accent,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.first, fallback],
            ),
          ),
        ),
        if (coverUrl.trim().isNotEmpty)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Image(
              image: CachedNetworkImageProvider(coverUrl),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (transformedCover ?? colors.first).withValues(alpha: 0.38),
                context.colors.surface1.withValues(alpha: 0.86),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Color? _themeCoverColor(
  ReadendarThemeId themeId,
  Color? coverColor,
  Color accent,
) {
  if (coverColor == null) return null;
  if (ReadendarThemes.byId(themeId).identity.effect !=
      ReadendarIdentityEffect.none) {
    final mixed = Color.lerp(coverColor, accent, 0.22)!;
    final hsl = HSLColor.fromColor(mixed);
    return hsl
        .withSaturation((hsl.saturation * 0.86).clamp(0.24, 0.76))
        .withLightness(hsl.lightness.clamp(0.24, 0.7))
        .toColor();
  } else {
    return coverColor;
  }
}

class _PremiumBookIdentityPainter extends CustomPainter {
  const _PremiumBookIdentityPainter({
    required this.identity,
    required this.progress,
    required this.primary,
    required this.secondary,
  });

  final ReadendarIdentityEffect identity;
  final double progress;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    switch (identity) {
      case ReadendarIdentityEffect.stormbound:
        _storm(canvas, size);
      case ReadendarIdentityEffect.evercourt:
        _velaris(canvas, size);
      case ReadendarIdentityEffect.neonMoon:
        _gate(canvas, size);
      case ReadendarIdentityEffect.trail:
        _trail(canvas, size);
      case ReadendarIdentityEffect.serpents:
        _serpents(canvas, size);
      case ReadendarIdentityEffect.thornCrown:
        _thorns(canvas, size);
      case ReadendarIdentityEffect.iridescent:
        _prism(canvas, size);
      case ReadendarIdentityEffect.lastLight:
        _mission(canvas, size);
      case ReadendarIdentityEffect.none || ReadendarIdentityEffect.ethereal:
        return;
    }
  }

  void _storm(Canvas canvas, Size size) {
    for (var index = 0; index < 22; index++) {
      final x = size.width * ((index * 0.071 + progress * 0.12) % 1);
      final y = size.height * ((index * 0.173 + progress * 0.8) % 1);
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 4, y + 13),
        Paint()
          ..color = primary.withValues(alpha: 0.2)
          ..strokeWidth = index % 6 == 0 ? 1 : 0.55,
      );
    }
    final lightning = Path()
      ..moveTo(size.width * 0.75, -2)
      ..lineTo(size.width * 0.7, size.height * 0.18)
      ..lineTo(size.width * 0.72, size.height * 0.21)
      ..lineTo(size.width * 0.64, size.height * 0.42)
      ..lineTo(size.width * 0.67, size.height * 0.45)
      ..lineTo(size.width * 0.55, size.height * 0.76);
    final branch = Path()
      ..moveTo(size.width * 0.64, size.height * 0.42)
      ..lineTo(size.width * 0.58, size.height * 0.5)
      ..lineTo(size.width * 0.54, size.height * 0.62);
    for (final bolt in [lightning, branch]) {
      canvas.drawPath(
        bolt,
        Paint()
          ..color = secondary.withValues(alpha: 0.18 + progress * 0.24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bolt == lightning ? 4 : 2.2
          ..strokeCap = StrokeCap.butt
          ..strokeJoin = StrokeJoin.bevel
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        bolt,
        Paint()
          ..color = secondary.withValues(alpha: 0.64)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bolt == lightning ? 1.05 : 0.65
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.bevel,
      );
    }
  }

  void _velaris(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final summit = Offset(size.width * 0.72, size.height * 0.4);
    final stars = <Offset>[
      Offset(size.width * 0.72, size.height * 0.23),
      Offset(size.width * 0.64, size.height * 0.31),
      Offset(size.width * 0.8, size.height * 0.31),
    ];
    final mountain = Path()
      ..moveTo(size.width * 0.34, size.height * 1.03)
      ..lineTo(size.width * 0.45, size.height * 0.73)
      ..lineTo(size.width * 0.56, size.height * 0.75)
      ..lineTo(summit.dx, summit.dy)
      ..lineTo(size.width * 0.83, size.height * 0.69)
      ..lineTo(size.width * 0.91, size.height * 0.58)
      ..lineTo(size.width * 1.04, size.height * 0.76)
      ..lineTo(size.width * 1.04, size.height * 1.03)
      ..close();
    canvas.drawPath(
      mountain,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.22),
            secondary.withValues(alpha: 0.08),
            primary.withValues(alpha: 0.16),
          ],
        ).createShader(mountain.getBounds()),
    );
    final ridge = Path()
      ..moveTo(size.width * 0.34, size.height * 1.03)
      ..lineTo(size.width * 0.45, size.height * 0.73)
      ..lineTo(size.width * 0.56, size.height * 0.75)
      ..lineTo(summit.dx, summit.dy)
      ..lineTo(size.width * 0.83, size.height * 0.69)
      ..lineTo(size.width * 0.91, size.height * 0.58)
      ..lineTo(size.width * 1.04, size.height * 0.76);
    canvas.drawPath(
      ridge,
      Paint()
        ..color = primary.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeJoin = StrokeJoin.bevel,
    );

    for (var index = 0; index < stars.length; index++) {
      final pulse =
          0.9 + math.sin(progress * math.pi * 0.84 + index * 1.8) * 0.09;
      _paintBookVelarisStar(
        canvas,
        stars[index],
        unit * (index == 0 ? 0.024 : 0.019) * pulse,
        (index == 0 ? primary : secondary).withValues(alpha: 0.78),
      );
    }
  }

  void _paintBookVelarisStar(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final star = Path();
    for (var index = 0; index < 16; index++) {
      final angle = -math.pi / 2 + index * math.pi / 8;
      final pointRadius = index.isEven
          ? radius * (index % 4 == 0 ? 1.8 : 1.0)
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

  void _gate(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width * 0.72, size.height * 0.52),
      width: size.shortestSide * 0.36,
      height: size.shortestSide * 0.66,
    );
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..shader = LinearGradient(
          colors: [primary, secondary],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(rect.left, rect.center.dy),
      Offset(rect.left, rect.bottom),
      Paint()..color = primary.withValues(alpha: 0.5),
    );
    canvas.drawLine(
      Offset(rect.right, rect.center.dy),
      Offset(rect.right, rect.bottom),
      Paint()..color = secondary.withValues(alpha: 0.5),
    );
  }

  void _trail(Canvas canvas, Size size) {
    final revealed = (10 * progress).ceil();
    for (var index = 0; index < revealed; index++) {
      final t = index / 9;
      _paw(
        canvas,
        Offset(
          size.width * (0.4 + t * 0.56),
          size.height * (0.86 - t * 0.58),
        ),
        4.2 + index % 2,
        index.isEven ? primary : secondary,
        claws: true,
      );
    }
  }

  void _serpents(Canvas canvas, Size size) {
    final path = Path();
    for (var index = 0; index <= 32; index++) {
      final t = index / 32;
      final point = Offset(
        size.width * (0.42 + t * 0.56),
        size.height * (0.5 + math.sin(t * math.pi * (3 + progress)) * 0.2),
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    _stroke(canvas, path, primary, 2);
  }

  void _paw(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    bool claws = false,
  }) {
    final paint = Paint()..color = color.withValues(alpha: 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, radius * 0.55),
        width: radius * 1.7,
        height: radius * 1.35,
      ),
      paint,
    );
    for (var toe = 0; toe < 4; toe++) {
      final x = center.dx + (toe - 1.5) * radius * 0.55;
      final toeCenter = Offset(
        x,
        center.dy - radius * (0.38 + (toe == 1 || toe == 2 ? 0.18 : 0)),
      );
      canvas.drawCircle(toeCenter, radius * 0.32, paint);
      if (claws) {
        canvas.drawLine(
          toeCenter - Offset(0, radius * 0.42),
          toeCenter - Offset(0, radius * 0.68),
          Paint()
            ..color = paint.color
            ..strokeWidth = 0.7
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _thorns(Canvas canvas, Size size) {
    final path = Path()..moveTo(size.width * 0.42, size.height * 0.88);
    for (var index = 0; index <= 8; index++) {
      path.lineTo(
        size.width * (0.42 + index * 0.065),
        size.height * (0.72 - math.sin(index * 0.8) * 0.28),
      );
    }
    _stroke(canvas, path, primary, 1.2);
    for (var index = 1; index <= (8 * progress).ceil(); index++) {
      final point = Offset(
        size.width * (0.42 + index * 0.065),
        size.height * (0.72 - math.sin(index * 0.8) * 0.28),
      );
      canvas.drawCircle(
        point,
        2.2,
        Paint()..color = secondary.withValues(alpha: 0.55),
      );
    }
  }

  void _prism(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final path = Path()
      ..moveTo(size.width * 0.46, size.height)
      ..lineTo(size.width * 0.68, 0)
      ..lineTo(size.width * 0.88, 0)
      ..lineTo(size.width * 0.65, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            primary.withValues(alpha: 0.06),
            secondary.withValues(alpha: 0.34 + progress * 0.18),
            primary.withValues(alpha: 0.08),
          ],
        ).createShader(bounds),
    );
  }

  void _mission(Canvas canvas, Size size) {
    final star = Offset(size.width * 0.76, size.height * 0.34);
    for (var index = 0; index < 3; index++) {
      final radius = size.shortestSide * (0.1 + index * 0.1);
      canvas.drawArc(
        Rect.fromCircle(center: star, radius: radius),
        -math.pi / 2 + index * 0.8,
        math.pi * (0.7 + progress * 0.75),
        false,
        Paint()
          ..color = (index.isEven ? primary : secondary).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
    canvas.drawCircle(
      star,
      3.2,
      Paint()..color = secondary.withValues(alpha: 0.7),
    );
  }

  void _stroke(Canvas canvas, Path path, Color color, double width) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumBookIdentityPainter oldDelegate) =>
      oldDelegate.identity != identity ||
      oldDelegate.progress != progress ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}

class _EtherealBookConstellationPainter extends CustomPainter {
  const _EtherealBookConstellationPainter({
    required this.progress,
    required this.lineColor,
    required this.starColor,
  });

  final double progress;
  final Color lineColor;
  final Color starColor;

  // Three compact sky-map silhouettes: a W, a dipper, and an hourglass with
  // a belt. Explicit topology avoids the long random zigzags that read as
  // decorative scratches instead of constellations.
  static const _normalizedStars = <Offset>[
    // W cluster.
    Offset(0.05, 0.18),
    Offset(0.12, 0.09),
    Offset(0.19, 0.19),
    Offset(0.27, 0.11),
    Offset(0.35, 0.22),
    // Dipper cluster.
    Offset(0.69, 0.11),
    Offset(0.80, 0.09),
    Offset(0.85, 0.23),
    Offset(0.73, 0.27),
    Offset(0.64, 0.23),
    Offset(0.56, 0.17),
    Offset(0.49, 0.19),
    // Hourglass and belt cluster.
    Offset(0.63, 0.61),
    Offset(0.82, 0.59),
    Offset(0.78, 0.86),
    Offset(0.59, 0.88),
    Offset(0.67, 0.72),
    Offset(0.72, 0.73),
    Offset(0.77, 0.74),
    Offset(0.72, 0.82),
  ];

  static const _edges = <(int, int)>[
    (0, 1),
    (1, 2),
    (2, 3),
    (3, 4),
    (5, 6),
    (6, 7),
    (7, 8),
    (8, 5),
    (8, 9),
    (9, 10),
    (10, 11),
    (12, 13),
    (13, 14),
    (14, 15),
    (15, 12),
    (12, 16),
    (16, 17),
    (17, 18),
    (18, 14),
    (17, 19),
  ];

  static const _majorStars = <int>{0, 2, 4, 5, 7, 10, 12, 13, 14, 15};

  @override
  void paint(Canvas canvas, Size size) {
    final stars = <Offset>[
      for (final point in _normalizedStars)
        Offset(point.dx * size.width, point.dy * size.height),
    ];
    final visible = (5 + progress * (stars.length - 5)).round().clamp(
      5,
      stars.length,
    );
    final line = Paint()
      ..color = lineColor.withValues(alpha: 0.28)
      ..strokeWidth = 0.75
      ..strokeCap = StrokeCap.round;
    for (final edge in _edges) {
      if (edge.$1 >= visible || edge.$2 >= visible) continue;
      canvas.drawLine(stars[edge.$1], stars[edge.$2], line);
    }

    final minorStar = Paint()..color = lineColor.withValues(alpha: 0.58);
    final majorStar = Paint()..color = starColor.withValues(alpha: 0.82);
    final halo = Paint()..color = starColor.withValues(alpha: 0.1);
    for (var index = 0; index < visible; index++) {
      final major = _majorStars.contains(index);
      if (major) canvas.drawCircle(stars[index], 4.2, halo);
      canvas.drawCircle(
        stars[index],
        major ? 1.65 : 0.85,
        major ? majorStar : minorStar,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EtherealBookConstellationPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.starColor != starColor;
}

class CoverPaletteExtractor {
  CoverPaletteExtractor._();

  static const _sampleSize = 24;
  static const _maxCacheEntries = 48;
  static final LinkedHashMap<Object, Future<Color?>> _cache =
      LinkedHashMap<Object, Future<Color?>>();

  static Future<Color?> dominantColor(
    ImageProvider provider,
    ImageConfiguration configuration,
  ) {
    final cached = _cache.remove(provider);
    if (cached != null) {
      _cache[provider] = cached;
      return cached;
    }
    final extraction = _extract(provider, configuration);
    _cache[provider] = extraction;
    if (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    return extraction;
  }

  static Future<Color?> _extract(
    ImageProvider provider,
    ImageConfiguration configuration,
  ) {
    final completer = Completer<Color?>();
    final stream = provider.resolve(configuration);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) async {
        stream.removeListener(listener);
        try {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawImageRect(
            info.image,
            Rect.fromLTWH(
              0,
              0,
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            ),
            Rect.fromLTWH(
              0,
              0,
              _sampleSize.toDouble(),
              _sampleSize.toDouble(),
            ),
            Paint()..filterQuality = FilterQuality.low,
          );
          final picture = recorder.endRecording();
          ui.Image? sample;
          try {
            sample = await picture.toImage(_sampleSize, _sampleSize);
            final data = await sample.toByteData();
            if (data == null) {
              if (!completer.isCompleted) completer.complete(null);
            } else {
              final bytes = data.buffer.asUint8List();
              var red = 0;
              var green = 0;
              var blue = 0;
              var samples = 0;
              for (var index = 0; index + 3 < bytes.length; index += 4) {
                if (bytes[index + 3] < 96) continue;
                red += bytes[index];
                green += bytes[index + 1];
                blue += bytes[index + 2];
                samples++;
              }
              if (!completer.isCompleted) {
                completer.complete(
                  samples == 0
                      ? null
                      : Color.fromARGB(
                          255,
                          red ~/ samples,
                          green ~/ samples,
                          blue ~/ samples,
                        ),
                );
              }
            }
          } finally {
            picture.dispose();
            sample?.dispose();
          }
        } on Object {
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      onError: (_, _) {
        if (!completer.isCompleted) completer.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}
