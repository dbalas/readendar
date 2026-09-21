import 'dart:ui' show loadFontFromList;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Asset key for the vendored Lucide TTF (name table aligned for iOS).
const kLucideFontAsset = 'assets/fonts/lucide.ttf';

/// Family names that must resolve to the Lucide TTF on every platform.
///
/// `lucide_flutter` registers `packages/lucide_flutter/LucideIcons`, but the
/// font's name table says `lucide`. iOS looks up the face by that internal
/// name and otherwise paints missing-glyph tofu (?).
const kLucideFontFamilies = <String>[
  'lucide',
  'LucideIcons',
  'packages/lucide_flutter/LucideIcons',
];

bool _lucideFontsLoaded = false;

@visibleForTesting
void debugResetIconFontsLoaded() {
  _lucideFontsLoaded = false;
}

@visibleForTesting
bool debugIconFontsLoaded() => _lucideFontsLoaded;

/// Registers the Lucide TTF under every family name iOS and Flutter look up.
///
/// Safe to call more than once. Failures are logged and do not abort startup:
/// Cupertino chrome still has `cupertino_icons` for nav-bar backs.
Future<void> ensureIconFontsLoaded() async {
  if (_lucideFontsLoaded) return;
  try {
    final data = await rootBundle.load(kLucideFontAsset);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await Future.wait([
      for (final family in kLucideFontFamilies)
        loadFontFromList(bytes, fontFamily: family),
    ]);
    _lucideFontsLoaded = true;
  } catch (e, s) {
    debugPrint('Lucide icon font failed to load: $e\n$s');
  }
}

/// Platform-native back glyph. Apple uses the Cupertino chevron (needs
/// `cupertino_icons`); Android keeps the Material arrow.
IconData rdBackIconData(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return CupertinoIcons.back;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return Icons.arrow_back;
  }
}

/// Platform-native close glyph.
IconData rdCloseIconData(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return CupertinoIcons.xmark;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return Icons.close;
  }
}

/// Apple [ActionIconTheme] so Material [BackButton] / [CloseButton] do not
/// fall through to rounded Material glyphs that read as tofu when the
/// Cupertino nav bar is also missing `cupertino_icons`.
ActionIconThemeData rdCupertinoActionIconTheme() {
  return ActionIconThemeData(
    backButtonIconBuilder: (context) => Icon(
      rdBackIconData(Theme.of(context).platform),
      color: IconTheme.of(context).color,
      size: 22,
    ),
    closeButtonIconBuilder: (context) => Icon(
      rdCloseIconData(Theme.of(context).platform),
      color: IconTheme.of(context).color,
      size: 22,
    ),
  );
}
