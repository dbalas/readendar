import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/empty_state.dart';

/// Worked empty scene for plan history — stacked plan-run cards with a
/// schedule cue (not a bare Lucide glyph).
class PlanHistoryEmptyArt extends StatelessWidget {
  const PlanHistoryEmptyArt({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const periwinkle = ReadendarTokens.periwinkle500;
    const teal = ReadendarTokens.teal500;
    return EmptyArtBackdrop(
      accent: periwinkle,
      height: 196,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Soft back run, slightly rotated — suggests a short history stack.
          Transform.translate(
            offset: const Offset(14, 12),
            child: Transform.rotate(
              angle: 0.06,
              child: Opacity(
                opacity: 0.42,
                child: EmptyArtCard(
                  background: c.bg,
                  border: c.line,
                  width: 124,
                  padding: const EdgeInsets.all(ReadendarTokens.sp2),
                  child: _ghostRun(c, periwinkle),
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
                        color: periwinkle.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(
                          ReadendarTokens.radiusSm,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        LucideIcons.calendarClock,
                        size: 18,
                        color: periwinkle,
                      ),
                    ),
                    const Spacer(),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [periwinkle, teal],
                        ),
                        borderRadius: BorderRadius.circular(
                          ReadendarTokens.radiusSm,
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          LucideIcons.calendarRange,
                          size: 14,
                          color: ReadendarTokens.paper50,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ReadendarTokens.sp3),
                _bar(92, 8, c.lineStrong),
                const SizedBox(height: 8),
                _bar(76, 6, c.line),
                const SizedBox(height: 10),
                _paceRow(c, periwinkle, teal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ghostRun(ReadendarColors c, Color accent) => Row(
    children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(56, 6, c.lineStrong),
            const SizedBox(height: 6),
            _bar(40, 5, c.line),
          ],
        ),
      ),
    ],
  );

  Widget _paceRow(ReadendarColors c, Color periwinkle, Color teal) => Row(
    children: [
      _chip(periwinkle),
      const SizedBox(width: 6),
      _chip(teal),
      const SizedBox(width: 8),
      Expanded(child: _bar(48, 5, c.line)),
    ],
  );

  Widget _chip(Color color) => Container(
    width: 18,
    height: 6,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(999),
    ),
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
