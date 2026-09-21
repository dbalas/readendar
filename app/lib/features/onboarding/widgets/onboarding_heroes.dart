import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';

/// The eight animated "hero" illustrations shown on the onboarding tour.
///
/// Each hero is built purely from Flutter widgets + brand tokens (no external
/// art assets). The `entrance` value each receives is the slide's scroll
/// *reveal* (0 off-centre → 1 centred), so the entrance cascade tracks the
/// swipe instead of a resetting controller. Any continuous *ambient* motion
/// lives in the hero's own controller, which is always disposed. Every hero
/// wraps itself in a [RepaintBoundary] so its repaint loop never dirties the
/// surrounding slide text.

/// Brand palette reused for decorative covers across the heroes.
const _palette = <Color>[
  ReadendarTokens.periwinkle500,
  ReadendarTokens.teal500,
  ReadendarTokens.sage500,
  ReadendarTokens.amber500,
  ReadendarTokens.wine400,
];

/// Eased 0→1 progress for the [begin]–[end] slice of a linear [value].
double _slice(double value, double begin, double end) {
  final t = ((value - begin) / (end - begin)).clamp(0.0, 1.0);
  return Curves.easeOut.transform(t);
}

const double _heroHeight = 220;

// ─────────────────────────────────────────────────────────────────────────
// 1 · Welcome — a preview cluster of the feature icons over a soft glow.
// ─────────────────────────────────────────────────────────────────────────

class WelcomeHero extends StatefulWidget {
  const WelcomeHero({required this.entrance, required this.accent, super.key});

  final double entrance;
  final Color accent;

  @override
  State<WelcomeHero> createState() => _WelcomeHeroState();
}

class _WelcomeHeroState extends State<WelcomeHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  // The headline features, in the same accents/icons as their own slides — a
  // little taste of what the tour is about to show (library · planner ·
  // calendar · quotes · more, matching the slide order that follows).
  static const _features = <(IconData, Color)>[
    (LucideIcons.libraryBig, ReadendarTokens.wine400),
    (LucideIcons.calendarRange, ReadendarTokens.teal500),
    (LucideIcons.calendar, ReadendarTokens.sage500),
    (LucideIcons.quote, ReadendarTokens.periwinkle600),
    (LucideIcons.sparkles, ReadendarTokens.amber500),
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: _heroHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft radial glow.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.accent.withValues(alpha: 0.22),
                    widget.accent.withValues(alpha: 0),
                  ],
                ),
              ),
              child: const SizedBox(width: 240, height: 240),
            ),
            // Drifting book glyphs.
            AnimatedBuilder(
              animation: _drift,
              builder: (_, _) => CustomPaint(
                size: const Size(260, _heroHeight),
                painter: _FloatingBooksPainter(_drift.value),
              ),
            ),
            // The feature badges, arching in.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _features.length; i++) _badge(i),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(int i) {
    final (icon, color) = _features[i];
    final t = _slice(widget.entrance, i * 0.1, i * 0.1 + 0.5);
    // Gentle upward arch: the middle badge sits highest.
    final x = 2 * i / (_features.length - 1) - 1; // -1..1
    final lift = (1 - x * x) * 16;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Transform.translate(
        offset: Offset(0, -lift * t),
        child: Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.5 + 0.5 * t,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, color: ReadendarTokens.paper50, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingBooksPainter extends CustomPainter {
  const _FloatingBooksPainter(this.phase);

  final double phase;

  // (dx, dy as fractions, width px, colour, base tilt).
  static const _books = <(double, double, double, Color, double)>[
    (0.12, 0.18, 30, ReadendarTokens.periwinkle400, -0.3),
    (0.86, 0.24, 26, ReadendarTokens.teal400, 0.35),
    (0.20, 0.78, 28, ReadendarTokens.amber500, 0.2),
    (0.82, 0.74, 24, ReadendarTokens.sage500, -0.22),
    (0.50, 0.06, 20, ReadendarTokens.wine400, 0.12),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint();
    final spine = Paint();
    for (var i = 0; i < _books.length; i++) {
      final (fx, fy, w, color, tilt) = _books[i];
      final h = w * 1.4;
      final bob = math.sin((phase * 2 * math.pi) + i) * 6;
      body.color = color.withValues(alpha: 0.16);
      spine.color = color.withValues(alpha: 0.28);

      canvas.save();
      canvas.translate(fx * size.width, fy * size.height + bob);
      canvas.rotate(tilt + math.sin(phase * 2 * math.pi + i) * 0.08);
      final cover = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(cover, const Radius.circular(3)),
        body,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cover.left, cover.top, w * 0.22, h),
          const Radius.circular(3),
        ),
        spine,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingBooksPainter old) => old.phase != phase;
}

// ─────────────────────────────────────────────────────────────────────────
// 2 · Calendar — a mini month grid that pops in, with a few pulsing dots.
// ─────────────────────────────────────────────────────────────────────────

class CalendarHero extends StatefulWidget {
  const CalendarHero({required this.entrance, required this.accent, super.key});

  final double entrance;
  final Color accent;

  @override
  State<CalendarHero> createState() => _CalendarHeroState();
}

class _CalendarHeroState extends State<CalendarHero>
    with SingleTickerProviderStateMixin {
  static const _cols = 7;
  static const _rows = 5;
  static const _eventCells = {9, 16, 23};
  static const _todayCell = 11;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: _heroHeight,
        child: Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final v = widget.entrance;
              final c = context.colors;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var row = 0; row < _rows; row++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var col = 0; col < _cols; col++)
                          _cell(row * _cols + col, row, col, v, c),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _cell(int index, int row, int col, double v, ReadendarColors c) {
    // Cascade diagonally from the top-left.
    final begin = ((row + col) / (_rows + _cols)) * 0.6;
    final t = _slice(v, begin, begin + 0.35);
    final isEvent = _eventCells.contains(index);
    final isToday = index == _todayCell;
    final pulse = 0.85 + 0.30 * _pulse.value;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.6 + 0.4 * t,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isToday
                  ? widget.accent.withValues(alpha: 0.16)
                  : c.surface2,
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusXs),
              border: isToday
                  ? Border.all(color: widget.accent, width: 1.5)
                  : null,
            ),
            alignment: Alignment.center,
            child: isEvent
                ? Transform.scale(
                    scale: pulse,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: widget.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 3 · Planner — a reading path that draws itself, lighting up milestones.
// ─────────────────────────────────────────────────────────────────────────

class PlannerHero extends StatelessWidget {
  const PlannerHero({required this.entrance, required this.accent, super.key});

  final double entrance;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: SizedBox(
        height: _heroHeight,
        child: Center(
          child: CustomPaint(
            size: const Size(260, 120),
            painter: _PlannerPathPainter(
              progress: Curves.easeInOut.transform(_slice(entrance, 0.15, 1)),
              accent: accent,
              track: c.line,
              unlitDot: c.lineStrong,
              dotCenter: c.surface1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannerPathPainter extends CustomPainter {
  _PlannerPathPainter({
    required this.progress,
    required this.accent,
    required this.track,
    required this.unlitDot,
    required this.dotCenter,
  });

  final double progress;
  final Color accent;
  final Color track;
  final Color unlitDot;
  final Color dotCenter;

  static const _milestones = [0.12, 0.37, 0.62, 0.88];

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = track;
    final dotCenterPaint = Paint()..color = dotCenter;
    final path = Path()..moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.15,
      size.width * 0.4,
      size.height * 0.95,
      size.width * 0.6,
      size.height * 0.5,
    );
    path.cubicTo(
      size.width * 0.78,
      size.height * 0.15,
      size.width * 0.9,
      size.height * 0.35,
      size.width,
      size.height * 0.22,
    );

    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);

    // Faint full track underneath.
    canvas.drawPath(path, trackPaint);
    // The drawn portion, in accent.
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );

    // Milestone dots light up as the line passes them.
    for (final m in _milestones) {
      final pos = metric.getTangentForOffset(metric.length * m)!.position;
      final lit = progress >= m;
      canvas.drawCircle(
        pos,
        lit ? 7 : 5,
        Paint()..color = lit ? accent : unlitDot,
      );
      if (lit) {
        canvas.drawCircle(pos, 3, dotCenterPaint);
      }
    }

    // Flag at the end once we've essentially arrived.
    if (progress > 0.96) {
      final end = metric.getTangentForOffset(metric.length)!.position;
      final pole = Paint()
        ..color = accent
        ..strokeWidth = 2;
      canvas.drawLine(end, end.translate(0, -22), pole);
      final flag = Path()
        ..moveTo(end.dx, end.dy - 22)
        ..lineTo(end.dx + 14, end.dy - 18)
        ..lineTo(end.dx, end.dy - 14)
        ..close();
      canvas.drawPath(flag, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _PlannerPathPainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.track != track ||
      old.unlitDot != unlitDot ||
      old.dotCenter != dotCenter;
}

// ─────────────────────────────────────────────────────────────────────────
// 4 · Roulette — a slow coverflow of book spines, the centre one highlighted.
// ─────────────────────────────────────────────────────────────────────────

class RouletteHero extends StatefulWidget {
  const RouletteHero({required this.entrance, required this.accent, super.key});

  final double entrance;
  final Color accent;

  @override
  State<RouletteHero> createState() => _RouletteHeroState();
}

class _RouletteHeroState extends State<RouletteHero>
    with SingleTickerProviderStateMixin {
  static const _count = 5;

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: _heroHeight,
        child: Center(
          child: AnimatedBuilder(
            animation: _spin,
            builder: (context, _) {
              final appear = _slice(widget.entrance, 0.25, 0.85);
              final phase = _spin.value * _count;
              // Build cards sorted so the most-centred renders last (on top).
              final cards = <(double, Widget)>[];
              for (var i = 0; i < _count; i++) {
                var rel = i - phase;
                // Wrap into [-count/2, count/2] so cards cycle smoothly.
                rel = (rel + _count / 2) % _count - _count / 2;
                cards.add((rel, _card(i, rel)));
              }
              cards.sort((a, b) => b.$1.abs().compareTo(a.$1.abs()));
              return Opacity(
                opacity: appear,
                child: Transform.scale(
                  scale: 0.85 + 0.15 * appear,
                  child: SizedBox(
                    width: 260,
                    height: _heroHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [for (final c in cards) c.$2],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _card(int i, double rel) {
    final scale = (1 - rel.abs() * 0.18).clamp(0.5, 1.0);
    final isCentre = rel.abs() < 0.5;
    // Mirror the real roulette: the matrix does perspective + coverflow turn,
    // while offset and scale ride on plain Transform widgets (avoids the
    // deprecated Matrix4.translate/scale).
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0016)
      ..rotateY(rel * 0.5);
    return Transform.translate(
      offset: Offset(rel * 64, 0),
      child: Transform(
        alignment: Alignment.center,
        transform: matrix,
        child: Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                if (isCentre)
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.4),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: BookCover(
              title: '',
              color: _palette[i % _palette.length],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 6 · Library import list: rows slide in and get ticked.
// ─────────────────────────────────────────────────────────────────────────

class LibraryHero extends StatelessWidget {
  const LibraryHero({required this.entrance, required this.accent, super.key});

  final double entrance;
  final Color accent;

  static const _rows = 4;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: SizedBox(
        height: _heroHeight,
        child: Center(
          child: SizedBox(
            width: 250,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _rows; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _row(i, c),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One imported book: a coloured spine, two placeholder text bars, and a tick
  /// that pops just after the row lands — reading as "rows being imported".
  Widget _row(int i, ReadendarColors c) {
    final begin = i * 0.16;
    final t = _slice(entrance, begin, begin + 0.45);
    final tick = _slice(entrance, begin + 0.25, begin + 0.7);
    final color = _palette[i % _palette.length];
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset((1 - t) * 40, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ReadendarTokens.sp3,
            vertical: ReadendarTokens.sp2,
          ),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
            border: Border.all(color: c.line),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 30,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: ReadendarTokens.sp4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _bar(110, 8, c.lineStrong),
                    const SizedBox(height: ReadendarTokens.sp2),
                    _bar(64, 7, c.line),
                  ],
                ),
              ),
              const SizedBox(width: ReadendarTokens.sp3),
              Transform.scale(
                scale: tick,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: ReadendarTokens.sage500,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 14,
                    color: ReadendarTokens.paper50,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(double width, double height, Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 7 · Quotes — a quote card whose lines type themselves in, ringed by the
//     three capture methods (pen · voice · photo) and a share badge.
// ─────────────────────────────────────────────────────────────────────────

class QuotesHero extends StatefulWidget {
  const QuotesHero({required this.entrance, required this.accent, super.key});

  final double entrance;
  final Color accent;

  @override
  State<QuotesHero> createState() => _QuotesHeroState();
}

class _QuotesHeroState extends State<QuotesHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  // (icon, colour, start offset off the card, end offset hugging a corner).
  static const _methods = <(IconData, Color, Offset, Offset)>[
    (
      LucideIcons.pencil,
      ReadendarTokens.teal500,
      Offset(-150, -60),
      Offset(-104, -46),
    ),
    (
      LucideIcons.mic,
      ReadendarTokens.sage500,
      Offset(150, -60),
      Offset(104, -46),
    ),
    (
      LucideIcons.camera,
      ReadendarTokens.amber500,
      Offset(-150, 60),
      Offset(-104, 46),
    ),
    (
      LucideIcons.share2,
      ReadendarTokens.wine400,
      Offset(150, 60),
      Offset(104, 46),
    ),
  ];

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: SizedBox(
        height: _heroHeight,
        child: Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final v = widget.entrance;
              final card = _slice(v, 0.1, 0.6);
              return SizedBox(
                width: 260,
                height: _heroHeight,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < _methods.length; i++) _method(i, v),
                    Opacity(
                      opacity: card,
                      child: Transform.scale(
                        scale: 0.85 + 0.15 * card,
                        child: _quoteCard(v, c),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _quoteCard(double v, ReadendarColors c) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(ReadendarTokens.sp5),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: widget.accent.withValues(alpha: 0.16),
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.quote, color: widget.accent, size: 26),
          const SizedBox(height: ReadendarTokens.sp3),
          // Three lines that "type" their way in with the entrance.
          _line(150, 0.35, 0.65, v),
          const SizedBox(height: ReadendarTokens.sp2),
          _line(150, 0.45, 0.75, v),
          const SizedBox(height: ReadendarTokens.sp2),
          _line(96, 0.55, 0.85, v),
          const SizedBox(height: ReadendarTokens.sp4),
          Row(
            children: [
              // Cover chip standing in for the source book.
              Container(
                width: 16,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: ReadendarTokens.sp3),
              _bar(56, 6, c.lineStrong),
              const Spacer(),
              // A softly pulsing favourite spark.
              Transform.scale(
                scale: 0.85 + 0.3 * _pulse.value,
                child: const Icon(
                  LucideIcons.sparkles,
                  size: 15,
                  color: ReadendarTokens.amberStar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A text line whose width fills over the [begin]–[end] slice of the entrance.
  Widget _line(double maxWidth, double begin, double end, double v) {
    final grow = _slice(v, begin, end);
    return Container(
      width: maxWidth * grow,
      height: 8,
      decoration: BoxDecoration(
        color: widget.accent.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
      ),
    );
  }

  Widget _bar(double width, double height, Color color) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
    ),
  );

  Widget _method(int i, double v) {
    final (icon, color, start, end) = _methods[i];
    // Stagger so even the last badge (i=3) fully settles by entrance ~1.0,
    // matching the other heroes — a wider window would leave it half-drawn.
    final t = _slice(v, 0.35 + i * 0.08, 0.35 + i * 0.08 + 0.4);
    final pos = Offset.lerp(start, end, t)!;
    final bob = math.sin(_pulse.value * math.pi + i) * 3;
    return Transform.translate(
      offset: Offset(pos.dx, pos.dy + bob),
      child: Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.5 + 0.5 * t,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(icon, color: ReadendarTokens.paper50, size: 18),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 8 · More — a 3+2 grid of the remaining delights (roulette · widgets · stats
//     · reading chapter · reminders) whose cards pop in and gently breathe.
// ─────────────────────────────────────────────────────────────────────────

class MoreHero extends StatefulWidget {
  const MoreHero({required this.entrance, required this.accent, super.key});

  final double entrance;
  final Color accent;

  @override
  State<MoreHero> createState() => _MoreHeroState();
}

class _MoreHeroState extends State<MoreHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    // (icon, accent, label) — the five "and more" delights, in grid order.
    final cards = <(IconData, Color, String)>[
      (
        LucideIcons.galleryHorizontal,
        ReadendarTokens.periwinkle600,
        l.tourMoreRoulette,
      ),
      (LucideIcons.layoutGrid, ReadendarTokens.teal500, l.tourMoreWidgets),
      (LucideIcons.chartColumn, ReadendarTokens.sage500, l.tourMoreStats),
      (LucideIcons.bookHeart, ReadendarTokens.wine400, l.readingChapterTitle),
      (LucideIcons.bell, ReadendarTokens.amber500, l.planReminders),
    ];
    const rowLengths = [3, 2];
    return RepaintBoundary(
      child: SizedBox(
        height: _heroHeight,
        child: Center(
          child: AnimatedBuilder(
            animation: _breathe,
            builder: (context, _) {
              var tileIndex = 0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final count in rowLengths)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var col = 0; col < count; col++)
                          _tile(tileIndex++, cards, c, compact: true),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tile(
    int i,
    List<(IconData, Color, String)> cards,
    ReadendarColors c, {
    bool compact = false,
  }) {
    final (icon, color, label) = cards[i];
    // Cascade in one card at a time, top-left first.
    final t = _slice(widget.entrance, i * 0.12, i * 0.12 + 0.5);
    // Each tile breathes on its own phase so the grid shimmers rather than pulses.
    final breath =
        0.9 + 0.1 * (0.5 + 0.5 * math.sin(_breathe.value * math.pi + i));
    return Padding(
      padding: const EdgeInsets.all(ReadendarTokens.sp2),
      child: Opacity(
        opacity: t,
        child: Transform.scale(
          scale: 0.7 + 0.3 * t,
          child: Container(
            width: compact ? 96 : 112,
            height: compact ? 74 : 88,
            padding: const EdgeInsets.symmetric(
              horizontal: ReadendarTokens.sp2,
            ),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
              border: Border.all(color: c.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.scale(
                  scale: breath,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ),
                const SizedBox(height: ReadendarTokens.sp2),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: c.fg2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
