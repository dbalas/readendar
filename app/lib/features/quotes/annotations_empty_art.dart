import 'package:flutter/material.dart';

import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/theme/annotation_category_style.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/empty_state.dart';

/// Worked empty scene for book annotations: four category cards, not the
/// quotes-only open-book illustration.
class AnnotationsEmptyArt extends StatelessWidget {
  const AnnotationsEmptyArt({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return EmptyArtBackdrop(
      accent: ReadendarTokens.annNote,
      height: 188,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(-42, 10),
            child: Transform.rotate(
              angle: -0.12,
              child: _miniCard(c, AnnotationCategory.theory, 86),
            ),
          ),
          Transform.translate(
            offset: const Offset(46, 14),
            child: Transform.rotate(
              angle: 0.14,
              child: _miniCard(c, AnnotationCategory.question, 86),
            ),
          ),
          EmptyArtCard(
            background: c.surface2,
            border: c.line,
            width: 132,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _glyph(AnnotationCategory.note, 36),
                    const Spacer(),
                    _glyph(AnnotationCategory.quote, 28),
                  ],
                ),
                const SizedBox(height: ReadendarTokens.sp3),
                _bar(96, 8, c.lineStrong),
                const SizedBox(height: 6),
                _bar(72, 7, c.line),
                const SizedBox(height: 6),
                _bar(48, 7, c.line),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniCard(ReadendarColors c, AnnotationCategory cat, double width) {
    return EmptyArtCard(
      background: c.surface1,
      border: c.line,
      width: width,
      padding: const EdgeInsets.all(ReadendarTokens.sp2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _glyph(cat, 22),
          const SizedBox(height: 8),
          _bar(width - 28, 5, c.line),
          const SizedBox(height: 4),
          _bar(width - 40, 5, c.line),
        ],
      ),
    );
  }

  Widget _glyph(AnnotationCategory cat, double size) {
    final hue = AnnotationCategoryStyle.hue(cat);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      ),
      alignment: Alignment.center,
      child: Icon(
        AnnotationCategoryStyle.icon(cat),
        size: size * 0.5,
        color: hue,
      ),
    );
  }

  Widget _bar(double width, double height, Color color) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
  );
}
