import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/empty_state.dart';

/// Empty scene for custom field definitions: a mini form card with labeled
/// field rows (text / number / select), so it reads as "fields" not a generic
/// list illustration.
class CustomFieldsEmptyArt extends StatelessWidget {
  const CustomFieldsEmptyArt({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const accent = ReadendarTokens.periwinkle500;
    const teal = ReadendarTokens.teal500;
    const amber = ReadendarTokens.amber500;
    return EmptyArtBackdrop(
      accent: accent,
      height: 200,
      child: EmptyArtCard(
        background: c.surface2,
        border: c.line,
        width: 168,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(
                      ReadendarTokens.radiusSm,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    LucideIcons.listPlus,
                    size: 15,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _bar(72, 7, c.lineStrong)),
                Icon(
                  LucideIcons.plus,
                  size: 14,
                  color: accent.withValues(alpha: 0.85),
                ),
              ],
            ),
            const SizedBox(height: ReadendarTokens.sp3),
            _labeledInput(
              c,
              icon: LucideIcons.type,
              iconColor: accent,
              labelWidth: 42,
              inputCue: _TextInputCue(colors: c),
            ),
            const SizedBox(height: 8),
            _labeledInput(
              c,
              icon: LucideIcons.hash,
              iconColor: teal,
              labelWidth: 36,
              inputCue: _NumberInputCue(colors: c, accent: teal),
            ),
            const SizedBox(height: 8),
            _labeledInput(
              c,
              icon: LucideIcons.chevronsUpDown,
              iconColor: amber,
              labelWidth: 48,
              inputCue: _SelectInputCue(colors: c, accent: amber),
            ),
          ],
        ),
      ),
    );
  }

  Widget _labeledInput(
    ReadendarColors c, {
    required IconData icon,
    required Color iconColor,
    required double labelWidth,
    required Widget inputCue,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor.withValues(alpha: 0.9)),
        const SizedBox(width: 6),
        SizedBox(width: labelWidth, child: _bar(labelWidth, 5, c.line)),
        const SizedBox(width: 8),
        Expanded(child: inputCue),
      ],
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

class _TextInputCue extends StatelessWidget {
  const _TextInputCue({required this.colors});
  final ReadendarColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.line),
      ),
      child: Container(
        width: 54,
        height: 5,
        decoration: BoxDecoration(
          color: colors.lineStrong,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _NumberInputCue extends StatelessWidget {
  const _NumberInputCue({required this.colors, required this.accent});
  final ReadendarColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.line),
      ),
      child: Text(
        '42',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: accent.withValues(alpha: 0.85),
          height: 1,
        ),
      ),
    );
  }
}

class _SelectInputCue extends StatelessWidget {
  const _SelectInputCue({required this.colors, required this.accent});
  final ReadendarColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: colors.lineStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            LucideIcons.chevronDown,
            size: 12,
            color: accent.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }
}
