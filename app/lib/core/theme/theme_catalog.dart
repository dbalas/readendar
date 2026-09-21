import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/input_theme.dart';
import 'package:readendar/core/theme/text_styles.dart';
import 'package:readendar/core/theme/theme_manifest.dart';

enum ReadendarThemeId {
  original('original'),
  jade('jade'),
  celestial('celestial'),
  ocean('ocean'),
  noir('noir'),
  sapphire('sapphire'),
  velvet('velvet'),
  aurora('aurora'),
  arcade('arcade'),
  pop('pop'),
  ethereal('ethereal'),
  stormbound('stormbound'),
  evercourt('evercourt'),
  neonMoon('neon_moon'),
  trail('trail'),
  serpents('serpents'),
  thornCrown('thorn_crown'),
  iridescent('iridescent'),
  lastLight('last_light');

  const ReadendarThemeId(this.wire);
  final String wire;

  static ReadendarThemeId fromWire(String? wire) => values.firstWhere(
    (value) => value.wire == wire,
    orElse: () => ReadendarThemeId.original,
  );
}

enum ReadendarBackgroundKind { solid, linear, radial }

enum ReadendarBackgroundEffect {
  none,
  ethereal,
  stormbound,
  evercourt,
  neonMoon,
  trail,
  serpents,
  thornCrown,
  iridescent,
  lastLight,
}

enum ReadendarIdentityEffect {
  none,
  ethereal,
  stormbound,
  evercourt,
  neonMoon,
  trail,
  serpents,
  thornCrown,
  iridescent,
  lastLight,
}

@immutable
class ReadendarThemeIdentity {
  const ReadendarThemeIdentity({
    required this.effect,
    required this.fantasy,
    required this.material,
    required this.motion,
    required this.readerReactive,
    required this.nativeArtwork,
  });

  final ReadendarIdentityEffect effect;
  final String fantasy;
  final String material;
  final String motion;
  final bool readerReactive;
  final bool nativeArtwork;
}

@immutable
class ReadendarBackgroundTreatment {
  const ReadendarBackgroundTreatment({
    required this.kind,
    required this.colors,
    this.grainOpacity = 0,
    this.effect = ReadendarBackgroundEffect.none,
  });

  final ReadendarBackgroundKind kind;
  final List<Color> colors;
  final double grainOpacity;
  final ReadendarBackgroundEffect effect;
}

ReadendarBackgroundTreatment _lerpBackgroundTreatment(
  ReadendarBackgroundTreatment a,
  ReadendarBackgroundTreatment b,
  double t,
) {
  final count = math.max(a.colors.length, b.colors.length);
  Color sample(List<Color> values, int index) {
    if (values.length == 1) return values.first;
    final normalized = index / math.max(1, count - 1);
    final position = normalized * (values.length - 1);
    final lower = position.floor();
    final upper = position.ceil();
    return Color.lerp(values[lower], values[upper], position - lower)!;
  }

  return ReadendarBackgroundTreatment(
    kind: t < 0.5 ? a.kind : b.kind,
    colors: [
      for (var index = 0; index < count; index++)
        Color.lerp(sample(a.colors, index), sample(b.colors, index), t)!,
    ],
    grainOpacity: lerpDouble(a.grainOpacity, b.grainOpacity, t)!,
    effect: t < 0.5 ? a.effect : b.effect,
  );
}

@immutable
class ReadendarComponentStyle extends ThemeExtension<ReadendarComponentStyle> {
  const ReadendarComponentStyle({
    required this.controlRadius,
    required this.cardRadius,
    required this.sheetRadius,
    required this.borderWidth,
    required this.overlayElevation,
    required this.cardShadow,
  });

  final double controlRadius;
  final double cardRadius;
  final double sheetRadius;
  final double borderWidth;
  final double overlayElevation;
  final List<BoxShadow> cardShadow;

  @override
  ReadendarComponentStyle copyWith({
    double? controlRadius,
    double? cardRadius,
    double? sheetRadius,
    double? borderWidth,
    double? overlayElevation,
    List<BoxShadow>? cardShadow,
  }) => ReadendarComponentStyle(
    controlRadius: controlRadius ?? this.controlRadius,
    cardRadius: cardRadius ?? this.cardRadius,
    sheetRadius: sheetRadius ?? this.sheetRadius,
    borderWidth: borderWidth ?? this.borderWidth,
    overlayElevation: overlayElevation ?? this.overlayElevation,
    cardShadow: cardShadow ?? this.cardShadow,
  );

  @override
  ReadendarComponentStyle lerp(
    covariant ReadendarComponentStyle? other,
    double t,
  ) {
    if (other == null) return this;
    return ReadendarComponentStyle(
      controlRadius: lerpDouble(controlRadius, other.controlRadius, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      sheetRadius: lerpDouble(sheetRadius, other.sheetRadius, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
      overlayElevation: lerpDouble(
        overlayElevation,
        other.overlayElevation,
        t,
      )!,
      cardShadow:
          BoxShadow.lerpList(cardShadow, other.cardShadow, t) ?? const [],
    );
  }
}

@immutable
class ReadendarThemeSpec extends ThemeExtension<ReadendarThemeSpec> {
  const ReadendarThemeSpec({required this.id, required this.background});

  final ReadendarThemeId id;
  final ReadendarBackgroundTreatment background;

  @override
  ReadendarThemeSpec copyWith({
    ReadendarThemeId? id,
    ReadendarBackgroundTreatment? background,
  }) => ReadendarThemeSpec(
    id: id ?? this.id,
    background: background ?? this.background,
  );

  @override
  ReadendarThemeSpec lerp(covariant ReadendarThemeSpec? other, double t) {
    if (other == null) return this;
    return ReadendarThemeSpec(
      id: t < 0.5 ? id : other.id,
      background: _lerpBackgroundTreatment(background, other.background, t),
    );
  }
}

@immutable
class ReadendarThemeDefinition {
  const ReadendarThemeDefinition({
    required this.id,
    required this.light,
    required this.dark,
    required this.style,
    required this.lightBackground,
    required this.darkBackground,
    required this.isPremium,
    required this.identity,
  });

  final ReadendarThemeId id;
  final ReadendarPalette light;
  final ReadendarPalette dark;
  final ReadendarComponentStyle style;
  final ReadendarBackgroundTreatment lightBackground;
  final ReadendarBackgroundTreatment darkBackground;
  final bool isPremium;
  final ReadendarThemeIdentity identity;

  ReadendarPalette palette(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  ReadendarColors colors(Brightness brightness) =>
      id == ReadendarThemeId.original
      ? ReadendarColors.of(brightness)
      : palette(brightness).semantic(brightness);

  ReadendarBackgroundTreatment background(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;
}

@immutable
class ReadendarPalette {
  const ReadendarPalette({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.accentHover,
    required this.accentPress,
    required this.accent2,
    required this.fgOnAccent,
  });

  final Color bg;
  final Color surface1;
  final Color surface2;
  final Color fg1;
  final Color fg2;
  final Color fg3;
  final Color line;
  final Color lineStrong;
  final Color accent;
  final Color accentHover;
  final Color accentPress;
  final Color accent2;
  final Color fgOnAccent;

  ReadendarColors semantic(Brightness brightness) {
    final base = ReadendarColors.of(brightness);
    return ReadendarColors(
      bg: bg,
      surface1: surface1,
      surface2: surface2,
      surfaceInv: brightness == Brightness.dark ? base.surfaceInv : fg1,
      fg1: fg1,
      fg2: fg2,
      fg3: fg3,
      fgFaint: fg3,
      fgDisabled: fg1.withValues(alpha: 0.38),
      fgOnAccent: fgOnAccent,
      fgLink: accentHover,
      line: line,
      lineStrong: lineStrong,
      accent: accent,
      accentHover: accentHover,
      accentPress: accentPress,
      accentSoftBg: accent.withValues(
        alpha: brightness == Brightness.dark ? 0.16 : 0.12,
      ),
      accentSoftFg: accentHover,
      accent2: accent2,
      accent2SoftBg: accent2.withValues(
        alpha: brightness == Brightness.dark ? 0.16 : 0.12,
      ),
      accent2SoftFg: accent2,
      highlight: base.highlight,
      highlightSoft: base.highlightSoft,
      success: base.success,
      successSoftBg: base.successSoftBg,
      successSoftFg: base.successSoftFg,
      warning: base.warning,
      warningSoftBg: base.warningSoftBg,
      warningSoftFg: base.warningSoftFg,
      danger: base.danger,
      dangerSoftBg: base.dangerSoftBg,
      dangerSoftFg: base.dangerSoftFg,
    );
  }
}

// GENERATED_THEME_CATALOG_START
const _paper = Color(0xFFFFFFFF);

class ReadendarThemes {
  ReadendarThemes._();

  static final List<ReadendarThemeDefinition> all = readendarThemeManifest
      .map(_fromManifest)
      .toList(growable: false);
  static final List<ReadendarThemeDefinition> standard = all
      .where((definition) => !definition.isPremium)
      .toList(growable: false);
  static final List<ReadendarThemeDefinition> premium = all
      .where((definition) => definition.isPremium)
      .toList(growable: false);

  static final ReadendarThemeDefinition original = byId(
    ReadendarThemeId.original,
  );
  static final ReadendarThemeDefinition jade = byId(ReadendarThemeId.jade);
  static final ReadendarThemeDefinition celestial = byId(
    ReadendarThemeId.celestial,
  );
  static final ReadendarThemeDefinition ocean = byId(ReadendarThemeId.ocean);
  static final ReadendarThemeDefinition noir = byId(ReadendarThemeId.noir);
  static final ReadendarThemeDefinition sapphire = byId(
    ReadendarThemeId.sapphire,
  );
  static final ReadendarThemeDefinition velvet = byId(ReadendarThemeId.velvet);
  static final ReadendarThemeDefinition aurora = byId(ReadendarThemeId.aurora);
  static final ReadendarThemeDefinition arcade = byId(ReadendarThemeId.arcade);
  static final ReadendarThemeDefinition pop = byId(ReadendarThemeId.pop);
  static final ReadendarThemeDefinition ethereal = byId(
    ReadendarThemeId.ethereal,
  );
  static final ReadendarThemeDefinition stormbound = byId(
    ReadendarThemeId.stormbound,
  );
  static final ReadendarThemeDefinition evercourt = byId(
    ReadendarThemeId.evercourt,
  );
  static final ReadendarThemeDefinition neonMoon = byId(
    ReadendarThemeId.neonMoon,
  );
  static final ReadendarThemeDefinition trail = byId(ReadendarThemeId.trail);
  static final ReadendarThemeDefinition serpents = byId(
    ReadendarThemeId.serpents,
  );
  static final ReadendarThemeDefinition thornCrown = byId(
    ReadendarThemeId.thornCrown,
  );
  static final ReadendarThemeDefinition iridescent = byId(
    ReadendarThemeId.iridescent,
  );
  static final ReadendarThemeDefinition lastLight = byId(
    ReadendarThemeId.lastLight,
  );

  static ReadendarThemeDefinition byId(ReadendarThemeId id) => all.firstWhere(
    (definition) => definition.id == id,
    orElse: () => all.first,
  );

  static ReadendarThemeDefinition _fromManifest(
    ReadendarThemeManifest manifest,
  ) {
    ReadendarPalette palette(ThemePaletteManifest value) => ReadendarPalette(
      bg: Color(value.bg),
      surface1: Color(value.surface1),
      surface2: Color(value.surface2),
      fg1: Color(value.fg1),
      fg2: Color(value.fg2),
      fg3: Color(value.fg3),
      line: Color(value.line),
      lineStrong: Color(value.lineStrong),
      accent: Color(value.accent),
      accentHover: Color(value.accentHover),
      accentPress: Color(value.accentPress),
      accent2: Color(value.accent2),
      fgOnAccent: Color(value.fgOnAccent),
    );

    ReadendarBackgroundTreatment background(
      ThemeBackgroundManifest value,
    ) => ReadendarBackgroundTreatment(
      kind: switch (value.type) {
        ThemeBackgroundType.solid => ReadendarBackgroundKind.solid,
        ThemeBackgroundType.linear => ReadendarBackgroundKind.linear,
        ThemeBackgroundType.radial => ReadendarBackgroundKind.radial,
      },
      colors: value.colors.map(Color.new).toList(growable: false),
      grainOpacity: value.grainOpacity,
      effect: switch (value.effect) {
        ThemeBackgroundEffect.none => ReadendarBackgroundEffect.none,
        ThemeBackgroundEffect.ethereal => ReadendarBackgroundEffect.ethereal,
        ThemeBackgroundEffect.stormbound =>
          ReadendarBackgroundEffect.stormbound,
        ThemeBackgroundEffect.evercourt => ReadendarBackgroundEffect.evercourt,
        ThemeBackgroundEffect.neonMoon => ReadendarBackgroundEffect.neonMoon,
        ThemeBackgroundEffect.trail => ReadendarBackgroundEffect.trail,
        ThemeBackgroundEffect.serpents => ReadendarBackgroundEffect.serpents,
        ThemeBackgroundEffect.thornCrown =>
          ReadendarBackgroundEffect.thornCrown,
        ThemeBackgroundEffect.iridescent =>
          ReadendarBackgroundEffect.iridescent,
        ThemeBackgroundEffect.lastLight => ReadendarBackgroundEffect.lastLight,
      },
    );

    final components = manifest.components;
    return ReadendarThemeDefinition(
      id: ReadendarThemeId.fromWire(manifest.id),
      light: palette(manifest.light),
      dark: palette(manifest.dark),
      style: ReadendarComponentStyle(
        controlRadius: components.controlRadius,
        cardRadius: components.cardRadius,
        sheetRadius: components.sheetRadius,
        borderWidth: components.borderWidth,
        overlayElevation: components.overlayElevation,
        cardShadow: components.shadows
            .map(
              (shadow) => BoxShadow(
                color: Color(shadow.color),
                offset: Offset(shadow.dx, shadow.dy),
                blurRadius: shadow.blur,
                spreadRadius: shadow.spread,
              ),
            )
            .toList(growable: false),
      ),
      lightBackground: background(manifest.lightBackground),
      darkBackground: background(manifest.darkBackground),
      isPremium: manifest.isPremium,
      identity: ReadendarThemeIdentity(
        effect: switch (manifest.identity.effect) {
          ThemeIdentityEffect.none => ReadendarIdentityEffect.none,
          ThemeIdentityEffect.ethereal => ReadendarIdentityEffect.ethereal,
          ThemeIdentityEffect.stormbound => ReadendarIdentityEffect.stormbound,
          ThemeIdentityEffect.evercourt => ReadendarIdentityEffect.evercourt,
          ThemeIdentityEffect.neonMoon => ReadendarIdentityEffect.neonMoon,
          ThemeIdentityEffect.trail => ReadendarIdentityEffect.trail,
          ThemeIdentityEffect.serpents => ReadendarIdentityEffect.serpents,
          ThemeIdentityEffect.thornCrown => ReadendarIdentityEffect.thornCrown,
          ThemeIdentityEffect.iridescent => ReadendarIdentityEffect.iridescent,
          ThemeIdentityEffect.lastLight => ReadendarIdentityEffect.lastLight,
        },
        fantasy: manifest.identity.fantasy,
        material: manifest.identity.material,
        motion: manifest.identity.motion,
        readerReactive: manifest.identity.readerReactive,
        nativeArtwork: manifest.identity.nativeArtwork,
      ),
    );
  }
}
// GENERATED_THEME_CATALOG_END

extension ReadendarThemeContext on BuildContext {
  ReadendarComponentStyle get componentStyle =>
      Theme.of(this).extension<ReadendarComponentStyle>() ??
      ReadendarThemes.original.style;

  ReadendarThemeSpec get readendarTheme =>
      Theme.of(this).extension<ReadendarThemeSpec>() ??
      ReadendarThemeSpec(
        id: ReadendarThemeId.original,
        background: ReadendarThemes.original.lightBackground,
      );
}

ThemeData applyReadendarTheme(
  ThemeData base,
  ReadendarThemeId id,
  Brightness brightness,
) {
  final definition = ReadendarThemes.byId(id);
  final colors = definition.colors(brightness);
  final style = definition.style;
  if (id == ReadendarThemeId.original) {
    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[
        ReadendarColorsTheme(colors),
        style,
        ReadendarThemeSpec(
          id: id,
          background: definition.background(brightness),
        ),
      ],
    );
  }
  final isDark = brightness == Brightness.dark;
  final scheme = base.colorScheme.copyWith(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: colors.fgOnAccent,
    primaryContainer: colors.accentSoftBg,
    onPrimaryContainer: colors.accentSoftFg,
    secondary: colors.accent2,
    onSecondary: isDark ? colors.bg : _paper,
    secondaryContainer: colors.accent2SoftBg,
    onSecondaryContainer: colors.accent2SoftFg,
    tertiary: colors.highlight,
    error: colors.danger,
    onError: isDark ? colors.bg : _paper,
    surface: colors.surface1,
    onSurface: colors.fg1,
    surfaceContainerHigh: colors.surface2,
    surfaceContainerHighest: colors.surface2,
    outline: colors.lineStrong,
    outlineVariant: colors.line,
  );
  final textTheme = ReadendarTextStyles.build(fg: colors.fg1, fg2: colors.fg2);
  final overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
  );
  final chromeLine = colors.lineStrong;
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(style.cardRadius),
    side: BorderSide(color: chromeLine, width: style.borderWidth),
  );
  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(style.controlRadius),
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor:
        definition.background(brightness).kind == ReadendarBackgroundKind.solid
        ? colors.bg
        : Colors.transparent,
    textTheme: textTheme,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: colors.bg,
      foregroundColor: colors.fg1,
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle: overlayStyle,
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: colors.accent,
      applyThemeToAll: true,
    ),
    cardTheme: base.cardTheme.copyWith(color: colors.surface1, shape: shape),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: colors.surface1,
      elevation: style.overlayElevation,
      shape: shape,
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: colors.surface1,
      elevation: style.overlayElevation,
      shape: shape,
    ),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: colors.surface1,
      elevation: style.overlayElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(style.sheetRadius),
        ),
        side: BorderSide(color: chromeLine, width: style.borderWidth),
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      indicatorColor: colors.accentSoftBg,
      backgroundColor: colors.bg,
      surfaceTintColor: colors.bg,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.accent
              : colors.fg2,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? colors.accent
              : colors.fg2,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: base.menuTheme.style?.copyWith(
        backgroundColor: WidgetStatePropertyAll(colors.surface1),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(style.overlayElevation),
        shape: WidgetStatePropertyAll(shape),
      ),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      subtitleTextStyle: TextStyle(
        color: colors.fg3,
        fontSize: 13,
        height: 1.25,
      ),
    ),
    inputDecorationTheme: buildInputDecorationTheme(
      border: colors.lineStrong,
      focus: colors.accent,
      label: colors.fg3,
      hint: colors.fg3,
      radius: style.controlRadius,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.fgOnAccent,
        minimumSize: const Size(44, 44),
        shape: controlShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.fg1,
        side: BorderSide(color: colors.lineStrong, width: style.borderWidth),
        minimumSize: const Size(44, 44),
        shape: controlShape,
      ),
    ),
    dividerTheme: base.dividerTheme.copyWith(color: colors.line),
    snackBarTheme: base.snackBarTheme.copyWith(
      contentTextStyle: TextStyle(color: colors.fg1),
    ),
    extensions: <ThemeExtension<dynamic>>[
      ReadendarColorsTheme(colors),
      style,
      ReadendarThemeSpec(id: id, background: definition.background(brightness)),
    ],
  );
}
