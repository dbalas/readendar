import 'package:flutter/material.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/count_badge.dart';

/// A compact, tappable "box" navigation card: a tinted leading icon tile with
/// the title (and optional subtitle) right beside it — no trailing chevron, so
/// the box stays narrow. Designed to sit two-up in a [Row] (Home and Profile
/// put "Mis estadísticas" + "Mis citas" side by side; the book detail puts
/// "Notas privadas" + "Citas" side by side), so it stretches to fill its height
/// when wrapped in an [IntrinsicHeight]. The title wraps to two lines when it
/// doesn't fit on one (e.g. "Mis estadísticas").
///
/// [tintBg]/[tintFg] color the icon tile; both default to the accent roles.
class NavBox extends StatelessWidget {
  const NavBox({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.tintBg,
    this.tintFg,
    this.dot = false,
    this.count,
    this.boldTitle = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Color? tintBg;
  final Color? tintFg;

  /// Whether the title renders in bold. Defaults to true; set false for a
  /// lighter, regular-weight label (e.g. the book-detail notes/quotes boxes).
  final bool boldTitle;

  /// Shows a small colored dot at the far right of the box, vertically
  /// centered, instead of a subtitle preview — used when the content is a
  /// single present/absent fact (e.g. whether a private note exists).
  final bool dot;

  /// Shows a numeric badge at the far right of the box, vertically centered,
  /// instead of a subtitle preview — used when the content is a list (e.g.
  /// how many quotes are saved). Null or zero renders no badge.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final indicatorColor = tintFg ?? c.accentSoftFg;
    Widget? indicator;
    if (dot) {
      indicator = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: indicatorColor,
          shape: BoxShape.circle,
        ),
      );
    } else if (count != null && count! > 0) {
      // Solid accent (not the box's soft tint) so this matches the count
      // badge on the events calendar icon exactly — same shape, same color.
      indicator = CountBadge(
        count: count!,
        color: c.accent,
        textColor: c.fgOnAccent,
        size: 22,
      );
    }
    final row = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tintBg ?? c.accentSoftBg,
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
          ),
          child: Icon(icon, size: 18, color: tintFg ?? c.accentSoftFg),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: boldTitle ? FontWeight.w700 : FontWeight.w400,
                  height: 1.15,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.2, color: c.fg2),
                ),
              ],
            ],
          ),
        ),
        if (indicator != null) ...[const SizedBox(width: 8), indicator],
      ],
    );
    return RdCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: row,
    );
  }
}

/// Two [NavBox]es side by side with equal heights (via [IntrinsicHeight]) and a
/// standard gap — the shared "two boxes, one beside the other" layout.
class NavBoxRow extends StatelessWidget {
  const NavBoxRow({required this.left, required this.right, super.key});

  final NavBox left;
  final NavBox right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}
