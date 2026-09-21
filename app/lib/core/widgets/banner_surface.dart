// Shared rendering for the Home welcome banner, used by both the live banner
// (_HomeHero) and the editor preview (_BannerPreview) so they can never drift —
// a change here updates the real banner and its preview together.

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/banner_presets.dart';
import 'package:readendar/core/theme/tokens.dart';

/// A rounded banner box that paints the chosen [style] (colour / gradient /
/// image), adds the legibility scrim for images, and lays [child] on top with
/// [padding]. Pass [localImagePath] to preview a not-yet-uploaded crop.
class BannerSurface extends StatelessWidget {
  const BannerSurface({
    required this.style,
    required this.child,
    super.key,
    this.localImagePath,
    this.apiBaseUrl,
    this.radius = ReadendarTokens.radiusLg,
    this.padding = const EdgeInsets.all(20),
  });

  final BannerStyle style;
  final Widget child;
  final String? localImagePath;
  final String? apiBaseUrl;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final showImage = localImagePath != null || style.kind == BannerKind.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: bannerFillDecoration(
                style,
                radius,
                localImagePath: localImagePath,
                apiBaseUrl: apiBaseUrl,
              ),
            ),
          ),
          if (showImage)
            Positioned.fill(
              child: DecoratedBox(decoration: bannerScrimDecoration(radius)),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// The white rounded box with the `bookMarked` glyph that anchors the banner.
/// The box is intentionally a fixed white brand constant; [glyphColor] tracks
/// the banner style (use [bannerSurfaceGlyph]).
class BannerIconBox extends StatelessWidget {
  const BannerIconBox({required this.glyphColor, super.key});

  final Color glyphColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ReadendarTokens.sp9,
      height: ReadendarTokens.sp9,
      decoration: BoxDecoration(
        color: ReadendarTokens.paper50,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      ),
      child: Icon(LucideIcons.bookMarked, color: glyphColor),
    );
  }
}

/// Glyph colour for the icon box: tracks the preset family, or a neutral dark
/// for an image banner (the glyph sits on the white box, not the photo). Pass
/// [localImagePath] so a staged image preview uses the image glyph immediately.
Color bannerSurfaceGlyph(BannerStyle style, {String? localImagePath}) =>
    localImagePath != null ? ReadendarTokens.ink700 : bannerGlyphColor(style);
