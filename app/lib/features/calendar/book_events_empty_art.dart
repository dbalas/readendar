import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/empty_state.dart';

/// Worked empty scene for a book's events list — calendar card with a soft
/// schedule cue (not a bare Lucide glyph).
class BookEventsEmptyArt extends StatelessWidget {
  const BookEventsEmptyArt({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const accent = ReadendarTokens.teal500;
    const amber = ReadendarTokens.amber500;
    return EmptyArtBackdrop(
      accent: accent,
      height: 188,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft back page, slightly rotated — suggests a stacked schedule.
          Transform.translate(
            offset: const Offset(12, 10),
            child: Transform.rotate(
              angle: 0.07,
              child: Opacity(
                opacity: 0.45,
                child: EmptyArtCard(
                  background: c.bg,
                  border: c.line,
                  width: 118,
                  padding: const EdgeInsets.all(ReadendarTokens.sp2),
                  child: _miniGrid(c),
                ),
              ),
            ),
          ),
          EmptyArtCard(
            background: c.surface2,
            border: c.line,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(
                          ReadendarTokens.radiusSm,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        LucideIcons.calendarDays,
                        size: 18,
                        color: accent,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      LucideIcons.calendarPlus,
                      size: 16,
                      color: amber.withValues(alpha: 0.9),
                    ),
                  ],
                ),
                const SizedBox(height: ReadendarTokens.sp3),
                _bar(88, 7, c.lineStrong),
                const SizedBox(height: 8),
                _dayRow(c, accent),
                const SizedBox(height: 6),
                _dayRow(c, amber, highlight: true),
                const SizedBox(height: 6),
                _dayRow(c, c.line),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniGrid(ReadendarColors c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _bar(64, 6, c.lineStrong),
      const SizedBox(height: 8),
      Row(
        children: [
          _dot(c.line),
          const SizedBox(width: 6),
          _dot(c.line),
          const SizedBox(width: 6),
          _dot(c.lineStrong),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          _dot(c.line),
          const SizedBox(width: 6),
          _dot(c.lineStrong),
          const SizedBox(width: 6),
          _dot(c.line),
        ],
      ),
    ],
  );

  Widget _dayRow(ReadendarColors c, Color mark, {bool highlight = false}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: mark.withValues(alpha: highlight ? 1 : 0.7),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _bar(highlight ? 72 : 56, 6, c.line)),
        const SizedBox(width: 8),
        _bar(22, 5, c.line),
      ],
    );
  }

  Widget _dot(Color color) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _bar(double width, double height, Color color) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
  );
}
