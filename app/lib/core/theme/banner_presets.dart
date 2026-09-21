// Home welcome-banner presets + rendering helpers.
//
// Presets are saturated brand fills (solids + gradients) with WHITE text,
// rendered identically in light and dark — the documented brand-fill exception
// (see CLAUDE.md "Theme & dark mode"). The ids here are the curated
// allowedBannerPresets list. There is no hosted API in this repository.
//
// Gradients are pairs of EXISTING tokens — no new hex codes — so this stays
// within the "no colours outside tokens.dart" rule.

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/media_urls.dart';
import 'package:readendar/core/theme/tokens.dart';

/// A curated banner background: either a solid colour or a gradient, plus the
/// colour for the glyph that sits in the white icon box.
class BannerPreset {
  const BannerPreset.solid(this.id, Color color, this.glyphColor)
    : _color = color,
      _gradient = null;
  const BannerPreset.gradient(this.id, List<Color> colors, this.glyphColor)
    : _color = null,
      _gradient = colors;

  final String id;

  /// Colour for the `bookMarked` glyph in the white icon box (tracks the
  /// preset's family so the banner reads as one piece).
  final Color glyphColor;

  final Color? _color;
  final List<Color>? _gradient;

  Color? get color => _color;

  Gradient? get gradient => _gradient == null
      ? null
      : LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
}

/// Display order in the editor swatch grid: solids first, then gradients.
const bannerPresetOrder = <String>[
  // solids
  'periwinkle', 'teal', 'sage', 'wine', 'amber', 'plum', 'pine', 'garnet',
  // gradients
  'ocean', 'sunset', 'forest', 'dusk', 'lagoon', 'meadow', 'ember', 'aurora',
];

const _defaultPresetId = 'periwinkle';

final Map<String, BannerPreset> bannerPresets = {
  for (final p in const <BannerPreset>[
    // ── solids (white text on the *500 shade; amber goes deeper for contrast)
    BannerPreset.solid(
      'periwinkle',
      ReadendarTokens.periwinkle500,
      ReadendarTokens.periwinkle600,
    ),
    BannerPreset.solid(
      'teal',
      ReadendarTokens.teal500,
      ReadendarTokens.teal600,
    ),
    BannerPreset.solid(
      'sage',
      ReadendarTokens.sage500,
      ReadendarTokens.sage600,
    ),
    BannerPreset.solid(
      'wine',
      ReadendarTokens.wine500,
      ReadendarTokens.wine600,
    ),
    BannerPreset.solid(
      'amber',
      ReadendarTokens.amber600,
      ReadendarTokens.amber800,
    ),
    BannerPreset.solid(
      'plum',
      ReadendarTokens.periwinkle700,
      ReadendarTokens.periwinkle800,
    ),
    BannerPreset.solid(
      'pine',
      ReadendarTokens.teal700,
      ReadendarTokens.teal800,
    ),
    BannerPreset.solid(
      'garnet',
      ReadendarTokens.wine700,
      ReadendarTokens.wine800,
    ),
    // ── gradients (glyph tracks the first stop's family)
    BannerPreset.gradient('ocean', [
      ReadendarTokens.periwinkle500,
      ReadendarTokens.teal500,
    ], ReadendarTokens.periwinkle600),
    BannerPreset.gradient('sunset', [
      ReadendarTokens.wine500,
      ReadendarTokens.amber500,
    ], ReadendarTokens.wine600),
    BannerPreset.gradient('forest', [
      ReadendarTokens.teal500,
      ReadendarTokens.sage500,
    ], ReadendarTokens.sage600),
    BannerPreset.gradient('dusk', [
      ReadendarTokens.periwinkle500,
      ReadendarTokens.wine500,
    ], ReadendarTokens.periwinkle600),
    BannerPreset.gradient('lagoon', [
      ReadendarTokens.teal500,
      ReadendarTokens.periwinkle500,
    ], ReadendarTokens.teal600),
    BannerPreset.gradient('meadow', [
      ReadendarTokens.sage500,
      ReadendarTokens.amber500,
    ], ReadendarTokens.sage600),
    BannerPreset.gradient('ember', [
      ReadendarTokens.amber500,
      ReadendarTokens.wine500,
    ], ReadendarTokens.amber800),
    BannerPreset.gradient('aurora', [
      ReadendarTokens.periwinkle500,
      ReadendarTokens.sage500,
    ], ReadendarTokens.periwinkle600),
  ])
    p.id: p,
};

/// Resolve a preset by id, falling back to the default (periwinkle) for an
/// unknown id — forward-compat with presets a newer server might add.
BannerPreset bannerPresetOrDefault(String id) =>
    bannerPresets[id] ?? bannerPresets[_defaultPresetId]!;

/// Whether [style] needs a dark scrim under the banner content (image only) so
/// the white greeting + metrics stay legible over arbitrary photos.
bool bannerNeedsScrim(BannerStyle style) => style.kind == BannerKind.image;

/// Canonicalizes banner image URLs (see [resolveUploadAssetUrl]).
String bannerImageUrl(String rawUrl, {String? apiBaseUrl}) =>
    resolveUploadAssetUrl(rawUrl, apiBaseUrl: apiBaseUrl);

/// The background fill decoration for a banner box of the given [radius].
/// For images, pass [localImagePath] to preview a not-yet-uploaded file.
BoxDecoration bannerFillDecoration(
  BannerStyle style,
  double radius, {
  String? localImagePath,
  String? apiBaseUrl,
}) {
  final br = BorderRadius.circular(radius);
  if (localImagePath != null) {
    return BoxDecoration(
      borderRadius: br,
      image: DecorationImage(
        image: FileImage(File(localImagePath)),
        fit: BoxFit.cover,
      ),
    );
  }
  switch (style.kind) {
    case BannerKind.image:
      final raw = style.imageUrl.trim();
      if (raw.startsWith('/') || raw.startsWith('file:')) {
        final path = raw.startsWith('file:')
            ? Uri.parse(raw).toFilePath()
            : raw;
        return BoxDecoration(
          borderRadius: br,
          image: DecorationImage(
            image: FileImage(File(path)),
            fit: BoxFit.cover,
          ),
        );
      }
      return BoxDecoration(
        borderRadius: br,
        image: DecorationImage(
          image: CachedNetworkImageProvider(
            bannerImageUrl(style.imageUrl, apiBaseUrl: apiBaseUrl),
          ),
          fit: BoxFit.cover,
        ),
      );
    case BannerKind.preset:
      final p = bannerPresetOrDefault(style.preset);
      return BoxDecoration(
        borderRadius: br,
        color: p.color,
        gradient: p.gradient,
      );
    case BannerKind.defaultStyle:
      return BoxDecoration(
        borderRadius: br,
        color: bannerPresets[_defaultPresetId]!.color,
      );
  }
}

/// A top-left→bottom-right dark scrim so white text stays readable over a photo.
/// Brightness-independent on purpose (a fixed scrim over arbitrary imagery).
BoxDecoration bannerScrimDecoration(double radius) => BoxDecoration(
  borderRadius: BorderRadius.circular(radius),
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33000000), Color(0x99000000)],
  ),
);

/// Colour for the glyph in the white icon box.
Color bannerGlyphColor(BannerStyle style) {
  switch (style.kind) {
    case BannerKind.image:
      return ReadendarTokens.ink700;
    case BannerKind.preset:
      return bannerPresetOrDefault(style.preset).glyphColor;
    case BannerKind.defaultStyle:
      return bannerPresets[_defaultPresetId]!.glyphColor;
  }
}
