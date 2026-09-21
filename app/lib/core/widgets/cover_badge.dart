import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/event_icon.dart';

/// A single round badge overlaid on a book cover — a filled circle with a
/// white outer ring and a soft shadow so it reads as a "sticker" floating over
/// the artwork. Holds an [imageUrl], an [icon], or a short
/// [label] (e.g. "+3"). When an [imageUrl] is given it fills the circle and
/// [background] stays behind it as the loading/transparent fallback.
///
/// The white ring + shadow formula matches the original `CompletedBadge` so the
/// whole family looks identical wherever it appears (calendar, rows, detail).
class CoverBadge extends StatelessWidget {
  const CoverBadge({
    required this.background,
    super.key,
    this.icon,
    this.label,
    this.imageUrl,
    this.size = 18,
    this.foreground = ReadendarTokens.paper50,
    this.semanticLabel,
  }) : assert(
         icon != null || label != null || imageUrl != null,
         'CoverBadge needs an icon, a label, or an imageUrl',
       );

  final Color background;
  final IconData? icon;
  final String? label;
  final String? imageUrl;
  final double size;
  final Color foreground;

  /// Screen-reader description of what this badge conveys (e.g. the event
  /// type). Null leaves the badge silent — fine when the surrounding tile
  /// already says it in text.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final badge = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        image: hasImage
            ? DecorationImage(
                image: CachedNetworkImageProvider(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
        border: Border.all(
          color: ReadendarTokens.paper50,
          width: (size * 0.1).clamp(1.0, 2.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: hasImage
          ? null
          : icon != null
          ? Icon(icon, size: size * 0.58, color: foreground)
          : Text(
              label!,
              maxLines: 1,
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.w800,
                height: 1,
                color: foreground,
              ),
            ),
    );
    if (semanticLabel == null) return badge;
    return Semantics(label: semanticLabel, child: badge);
  }
}

/// Formats a half-star rating for display: a whole value drops the decimal
/// ("4"), a half shows one decimal ("4.5").
String fmtRating(double r) =>
    r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);

/// Picks the star icon for slot [index] (1..5) given a half-star [value]: full,
/// half, or empty. Shared by the read-only display and the interactive picker.
IconData starIconForRating(double value, int index) {
  if (value >= index) return Icons.star_rounded;
  if (value >= index - 0.5) return Icons.star_half_rounded;
  return Icons.star_outline_rounded;
}

/// A small pill overlaid on a book cover showing the user's private rating: a
/// filled star + the numeric value (e.g. "★ 4.5"). Shares the white-ring +
/// shadow "sticker" treatment of [CoverBadge] so it reads over any artwork.
class RatingBadge extends StatelessWidget {
  const RatingBadge({required this.rating, super.key, this.height = 18});

  final double rating;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.26),
      decoration: BoxDecoration(
        color: ReadendarTokens.amber500,
        borderRadius: BorderRadius.circular(height),
        border: Border.all(
          color: ReadendarTokens.paper50,
          width: (height * 0.1).clamp(1.0, 2.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: height * 0.74,
            color: ReadendarTokens.paper50,
          ),
          SizedBox(width: height * 0.06),
          Text(
            fmtRating(rating),
            style: TextStyle(
              fontSize: height * 0.58,
              fontWeight: FontWeight.w800,
              height: 1,
              color: ReadendarTokens.paper50,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlays the cover-badge system on top of a book [cover]:
///
///   right edge, top→bottom:  TYPE (always) · COUNT (+N)
///   bottom-left, inset:      COMPLETION (✓)
///
/// [coverWidth] drives badge sizing so the same widget scales from the small
/// calendar cell to a full-size cover. The right-side stack always sits apart
/// (never overlapping).
class BadgedCover extends StatelessWidget {
  const BadgedCover({
    required this.cover,
    required this.coverWidth,
    required this.eventType,
    super.key,
    this.extraCount = 0,
    this.completed = false,
  });

  /// The cover artwork to badge (already sized/clipped by the caller).
  final Widget cover;

  /// Logical width of [cover] in px — used only to size the badges.
  final double coverWidth;

  /// Always rendered as the top, fixed anchor of the right-side stack.
  final EventType eventType;

  /// Number of *additional* events beyond the primary one; shows "+N" when > 0.
  final int extraCount;

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final d = (coverWidth * 0.5).clamp(15.0, 26.0);
    final pitch = d * 1.1; // tight but never overlapping.

    final rightStack = <Widget>[
      CoverBadge(
        background: ReadendarTokens.paper50,
        foreground: eventType.color,
        icon: eventType.icon,
        size: d,
        semanticLabel: eventType.label(l),
      ),
      if (extraCount > 0)
        CoverBadge(
          background: ReadendarTokens.ink700,
          label: '+$extraCount',
          size: d,
        ),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        cover,
        // Right edge: vertical stack anchored to the top, biting the border.
        Positioned(
          top: -d * 0.18,
          right: -d * 0.35,
          child: SizedBox(
            width: d,
            height: (rightStack.length - 1) * pitch + d,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < rightStack.length; i++)
                  Positioned(top: i * pitch, child: rightStack[i]),
              ],
            ),
          ),
        ),
        // Completion: opposite corner, inset (contained, not overhanging).
        if (completed)
          Positioned(
            left: d * 0.22,
            bottom: d * 0.22,
            child: CoverBadge(
              background: ReadendarTokens.sage600,
              icon: Icons.check_rounded,
              size: d,
              semanticLabel: l.a11yCompleted,
            ),
          ),
      ],
    );
  }
}
