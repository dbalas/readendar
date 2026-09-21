import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/empty_state.dart';

/// Catalog-search empty scene — ghost result rows (cover + title/author),
/// previewing the list that appears after a search. Not the rotated-card
/// pattern used by quotes / events empties.
class SearchEmptyArt extends StatelessWidget {
  const SearchEmptyArt({super.key});

  static const List<Color> _covers = [
    ReadendarTokens.periwinkle500,
    ReadendarTokens.teal500,
    ReadendarTokens.amber500,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return EmptyArtBackdrop(
      accent: ReadendarTokens.periwinkle500,
      height: 248,
      // [EmptyArtBackdrop] becomes shorter under the keyboard. Scale the
      // fixed-height ghost rows with it instead of overflowing the stack.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _covers.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Opacity(
                  opacity: 1.0 - (i * 0.28),
                  child: _GhostResultRow(
                    cover: _covers[i],
                    titleWidth: i == 0 ? 108 : (i == 1 ? 92 : 76),
                    authorWidth: i == 0 ? 72 : (i == 1 ? 58 : 48),
                    colors: c,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostResultRow extends StatelessWidget {
  const _GhostResultRow({
    required this.cover,
    required this.titleWidth,
    required this.authorWidth,
    required this.colors,
  });

  final Color cover;
  final double titleWidth;
  final double authorWidth;
  final ReadendarColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
        border: Border.all(color: colors.line),
        boxShadow: [
          BoxShadow(
            color: ReadendarTokens.ink900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cover stub — matches BookCoverSize.xs proportions (~36×54).
          Container(
            width: 32,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cover.withValues(alpha: 0.85),
                  cover.withValues(alpha: 0.45),
                ],
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 3,
                height: 48,
                decoration: BoxDecoration(
                  color: ReadendarTokens.ink900.withValues(alpha: 0.14),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(ReadendarTokens.radiusSm),
                    bottomLeft: Radius.circular(ReadendarTokens.radiusSm),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(titleWidth, 8, colors.lineStrong),
                const SizedBox(height: 6),
                _bar(authorWidth, 6, colors.line),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: colors.fgFaint,
          ),
        ],
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
