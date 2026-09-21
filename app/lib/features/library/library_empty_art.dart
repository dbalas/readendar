import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/empty_state.dart';

/// First-run library empty scene — a tight fan of waiting covers on one shelf
/// baseline (not a bare Lucide glyph). Covers compose in with a staggered
/// entrance, same pattern as other tab heroes.
class LibraryEmptyArt extends StatefulWidget {
  const LibraryEmptyArt({super.key});

  // Designed scene size. Scales lightly with [EmptyStateDensity].
  static const double sceneW = 220;
  static const double sceneH = 168;

  /// Shared baseline: every cover's bottom-center sits on this Y.
  static const double shelfY = 148;

  @override
  State<LibraryEmptyArt> createState() => _LibraryEmptyArtState();
}

class _LibraryEmptyArtState extends State<LibraryEmptyArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_entrance.forward());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Instant settle under reduce-motion / widget-test disableAnimations so
    // pumpAndSettle can finish.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// Staggered 0→1 slice for cover [i] (hero=0 … outer=4).
  double _slice(double t, int i) {
    final raw = ((t - i * 0.09) / 0.55).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final density = EmptyStateDensity.of(context);
    final densityScale = lerpDouble(0.9, 1.0, density)!;
    const accent = ReadendarTokens.periwinkle500;
    const centerX = LibraryEmptyArt.sceneW / 2;

    return EmptyArtBackdrop(
      accent: accent,
      height: 208,
      child: AnimatedBuilder(
        animation: _entrance,
        builder: (context, _) {
          final t = Curves.easeOut.transform(
            _entrance.value.clamp(0.0, 1.0),
          );
          final shelfT = Curves.easeOut.transform(
            ((t - 0.05) / 0.45).clamp(0.0, 1.0),
          );
          final heroT = _slice(t, 0);
          final midLT = _slice(t, 1);
          final midRT = _slice(t, 2);
          final outLT = _slice(t, 3);
          final outRT = _slice(t, 4);
          final cueT = Curves.easeOutBack.transform(
            ((t - 0.55) / 0.4).clamp(0.0, 1.0),
          );

          return Transform.scale(
            scale: densityScale,
            child: SizedBox(
              width: LibraryEmptyArt.sceneW,
              height: LibraryEmptyArt.sceneH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Soft shelf — fades in under the assembling fan.
                  Positioned(
                    left: 28,
                    right: 28,
                    top: LibraryEmptyArt.shelfY - 3,
                    child: Opacity(
                      opacity: shelfT,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              c.line.withValues(alpha: 0),
                              c.lineStrong.withValues(alpha: 0.5 * shelfT),
                              c.line.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Back-left — teal, fans out last.
                  _animatedCover(
                    progress: outLT,
                    pivotX: lerpDouble(centerX, 58, outLT)!,
                    width: 48,
                    height: 76,
                    angle: lerpDouble(0, -0.18, outLT)!,
                    child: _CoverStub(
                      color: ReadendarTokens.teal500,
                      width: 48,
                      height: 76,
                      colors: c,
                    ),
                  ),
                  // Back-right — wine.
                  _animatedCover(
                    progress: outRT,
                    pivotX: lerpDouble(centerX, 162, outRT)!,
                    width: 48,
                    height: 76,
                    angle: lerpDouble(0, 0.18, outRT)!,
                    child: _CoverStub(
                      color: ReadendarTokens.wine400,
                      width: 48,
                      height: 76,
                      colors: c,
                    ),
                  ),
                  // Mid-left — amber.
                  _animatedCover(
                    progress: midLT,
                    pivotX: lerpDouble(centerX, 86, midLT)!,
                    width: 52,
                    height: 88,
                    angle: lerpDouble(0, -0.08, midLT)!,
                    child: _CoverStub(
                      color: ReadendarTokens.amber500,
                      width: 52,
                      height: 88,
                      colors: c,
                    ),
                  ),
                  // Mid-right — sage.
                  _animatedCover(
                    progress: midRT,
                    pivotX: lerpDouble(centerX, 134, midRT)!,
                    width: 52,
                    height: 88,
                    angle: lerpDouble(0, 0.08, midRT)!,
                    child: _CoverStub(
                      color: ReadendarTokens.sage500,
                      width: 52,
                      height: 88,
                      colors: c,
                    ),
                  ),
                  // Hero — lands first; bookmark / + cue pop in late.
                  _animatedCover(
                    progress: heroT,
                    pivotX: centerX,
                    width: _HeroCover.width,
                    height: _HeroCover.height,
                    angle: 0,
                    child: _HeroCover(colors: c, cueProgress: cueT),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Cover rises, scales, and fades in while pivoting onto the shelf.
  Widget _animatedCover({
    required double progress,
    required double pivotX,
    required double width,
    required double height,
    required double angle,
    required Widget child,
  }) {
    final rise = (1 - progress) * 18;
    final scale = 0.72 + 0.28 * progress;
    return Positioned(
      left: pivotX - width / 2,
      top: LibraryEmptyArt.shelfY - height + rise,
      child: Opacity(
        opacity: progress,
        child: Transform.rotate(
          angle: angle,
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.bottomCenter,
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      ),
    );
  }
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.colors, required this.cueProgress});

  final ReadendarColors colors;
  final double cueProgress;

  static const double width = 60;
  static const double height = 100;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _CoverStub(
            color: ReadendarTokens.periwinkle500,
            width: width,
            height: height,
            colors: colors,
            hero: true,
          ),
          // Bookmark peeks from the top-left — opposite corner from the +.
          Positioned(
            top: -10,
            left: 12,
            child: Opacity(
              opacity: cueProgress.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - cueProgress) * 8),
                child: Transform.rotate(
                  angle: -0.06,
                  child: Container(
                    width: 9,
                    height: 26,
                    decoration: BoxDecoration(
                      color: ReadendarTokens.amber500,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ReadendarTokens.ink900.withValues(alpha: 0.12),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Add cue pops onto the hero corner after the fan settles.
          Positioned(
            right: -10,
            top: -8,
            child: Opacity(
              opacity: cueProgress.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.6 + 0.4 * cueProgress,
                child: _AddBadge(colors: colors),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverStub extends StatelessWidget {
  const _CoverStub({
    required this.color,
    required this.width,
    required this.height,
    required this.colors,
    this.hero = false,
  });

  final Color color;
  final double width;
  final double height;
  final ReadendarColors colors;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(ReadendarTokens.radiusSm);
    // Fixed spine width — same cue as real BookCover stubs / SearchEmptyArt.
    const spine = 3.0;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.line),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            Color.lerp(color, ReadendarTokens.ink900, 0.22)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: ReadendarTokens.ink900.withValues(alpha: hero ? 0.16 : 0.1),
            blurRadius: hero ? 12 : 7,
            offset: Offset(0, hero ? 5 : 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: spine,
              height: height,
              decoration: BoxDecoration(
                color: ReadendarTokens.ink900.withValues(alpha: 0.18),
                borderRadius: BorderRadius.only(
                  topLeft: radius.topLeft,
                  bottomLeft: radius.bottomLeft,
                ),
              ),
            ),
          ),
          if (hero)
            Padding(
              padding: const EdgeInsets.fromLTRB(spine + 8, 16, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width * 0.48, 5, Colors.white.withValues(alpha: 0.78)),
                  const SizedBox(height: 5),
                  _bar(width * 0.32, 4, Colors.white.withValues(alpha: 0.45)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(double w, double h, Color color) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
  );
}

class _AddBadge extends StatelessWidget {
  const _AddBadge({required this.colors});

  final ReadendarColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: colors.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: colors.line),
        boxShadow: [
          BoxShadow(
            color: ReadendarTokens.ink900.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.plus,
        size: 15,
        color: ReadendarTokens.periwinkle500,
      ),
    );
  }
}
