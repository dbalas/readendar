/// Platform-neutral source of truth for every Readendar visual theme.
///
/// Keep this file free of Flutter imports so `tool/generate_native_themes.dart`
/// can consume it with the standalone Dart VM. Android and iOS theme tables and
/// Android widget drawables are generated from this manifest.
enum ThemeBackgroundType { solid, linear, radial }

enum ThemeBackgroundEffect {
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

/// Cross-surface identity rendered by a premium theme.
///
/// Palette and component geometry are not enough to qualify a theme as
/// premium. This value selects one coherent art direction across the app
/// canvas, reading progress, book detail, celebrations, and
/// native widgets. Renderers must switch on this owner instead of inferring an
/// identity from a theme ID or a dominant color.
enum ThemeIdentityEffect {
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

class ThemeIdentityManifest {
  const ThemeIdentityManifest({
    required this.effect,
    required this.fantasy,
    required this.material,
    required this.motion,
    this.readerReactive = false,
    this.nativeArtwork = false,
  });

  static const standard = ThemeIdentityManifest(
    effect: ThemeIdentityEffect.none,
    fantasy: 'Readendar core',
    material: 'semantic color',
    motion: 'platform standard',
  );

  final ThemeIdentityEffect effect;

  /// Internal creative brief. Never displayed directly to users.
  final String fantasy;
  final String material;
  final String motion;
  final bool readerReactive;
  final bool nativeArtwork;
}

class ThemePaletteManifest {
  const ThemePaletteManifest({
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

  final int bg;
  final int surface1;
  final int surface2;
  final int fg1;
  final int fg2;
  final int fg3;
  final int line;
  final int lineStrong;
  final int accent;
  final int accentHover;
  final int accentPress;
  final int accent2;
  final int fgOnAccent;
}

class ThemeShadowManifest {
  const ThemeShadowManifest({
    required this.color,
    required this.dx,
    required this.dy,
    this.blur = 0,
    this.spread = 0,
  });

  final int color;
  final double dx;
  final double dy;
  final double blur;
  final double spread;
}

class ThemeComponentManifest {
  const ThemeComponentManifest({
    required this.controlRadius,
    required this.cardRadius,
    required this.sheetRadius,
    required this.borderWidth,
    required this.overlayElevation,
    this.shadows = const [],
  });

  final double controlRadius;
  final double cardRadius;
  final double sheetRadius;
  final double borderWidth;
  final double overlayElevation;
  final List<ThemeShadowManifest> shadows;
}

class ThemeBackgroundManifest {
  const ThemeBackgroundManifest({
    required this.type,
    required this.colors,
    this.grainOpacity = 0,
    this.effect = ThemeBackgroundEffect.none,
  });

  final ThemeBackgroundType type;
  final List<int> colors;
  final double grainOpacity;
  final ThemeBackgroundEffect effect;
}

class ReadendarThemeManifest {
  const ReadendarThemeManifest({
    required this.id,
    required this.light,
    required this.dark,
    required this.components,
    required this.lightBackground,
    required this.darkBackground,
    this.isPremium = false,
    this.identity = ThemeIdentityManifest.standard,
  });

  final String id;
  final ThemePaletteManifest light;
  final ThemePaletteManifest dark;
  final ThemeComponentManifest components;
  final ThemeBackgroundManifest lightBackground;
  final ThemeBackgroundManifest darkBackground;
  final bool isPremium;
  final ThemeIdentityManifest identity;
}

const readendarThemeManifest = <ReadendarThemeManifest>[
  ReadendarThemeManifest(
    id: 'original',
    light: ThemePaletteManifest(
      bg: 0xFFFAF5EF,
      surface1: 0xFFFFFFFF,
      surface2: 0xFFF7F7F5,
      fg1: 0xFF0F1014,
      fg2: 0xFF404040,
      fg3: 0xFF5E5E5B,
      line: 0xFFE5E5E0,
      lineStrong: 0xFFC9C9C2,
      accent: 0xFF7479D6,
      accentHover: 0xFF5A5FBC,
      accentPress: 0xFF44489A,
      accent2: 0xFF2A8F7D,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF0E1018,
      surface1: 0xFF161A26,
      surface2: 0xFF1F2433,
      fg1: 0xFFF2F2F5,
      fg2: 0xFFB7B8C0,
      fg3: 0xFF808290,
      line: 0x1AF2F2F5,
      lineStrong: 0x33F2F2F5,
      accent: 0xFFA8ADDD,
      accentHover: 0xFFC5C9EA,
      accentPress: 0xFFE2E4F4,
      accent2: 0xFF64BCAC,
      fgOnAccent: 0xFF0F1014,
    ),
    components: ThemeComponentManifest(
      controlRadius: 8,
      cardRadius: 12,
      sheetRadius: 20,
      borderWidth: 1,
      overlayElevation: 6,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.solid,
      colors: [0xFFFAF5EF],
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.solid,
      colors: [0xFF0E1018],
    ),
  ),
  ReadendarThemeManifest(
    id: 'jade',
    light: ThemePaletteManifest(
      bg: 0xFFF1F7F3,
      surface1: 0xFFFCFDFC,
      surface2: 0xFFDDECE4,
      fg1: 0xFF11261D,
      fg2: 0xFF355447,
      fg3: 0xFF577065,
      line: 0xFFC4D9CE,
      lineStrong: 0xFF8FAD9E,
      accent: 0xFF12614A,
      accentHover: 0xFF0C4937,
      accentPress: 0xFF073225,
      accent2: 0xFFA06A1B,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF071410,
      surface1: 0xFF0E211A,
      surface2: 0xFF173328,
      fg1: 0xFFEEF8F2,
      fg2: 0xFFBBD2C6,
      fg3: 0xFF839F91,
      line: 0xFF29483B,
      lineStrong: 0xFF3F6754,
      accent: 0xFF8DD9B7,
      accentHover: 0xFFB7E8D2,
      accentPress: 0xFFDCF4E8,
      accent2: 0xFFE2B865,
      fgOnAccent: 0xFF0B2418,
    ),
    components: ThemeComponentManifest(
      controlRadius: 14,
      cardRadius: 20,
      sheetRadius: 30,
      borderWidth: 1,
      overlayElevation: 6,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFFF1F7F3, 0xFFDDEDE5, 0xFFF7EBCF],
      grainOpacity: 0.01,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF12382B, 0xFF071410, 0xFF2A2314],
      grainOpacity: 0.01,
    ),
  ),
  ReadendarThemeManifest(
    id: 'celestial',
    light: ThemePaletteManifest(
      bg: 0xFFF3F4FC,
      surface1: 0xFFFCFCFF,
      surface2: 0xFFE4E8F8,
      fg1: 0xFF111A3B,
      fg2: 0xFF394569,
      fg3: 0xFF5F6988,
      line: 0xFFC9CFE6,
      lineStrong: 0xFF939DC4,
      accent: 0xFF263E91,
      accentHover: 0xFF1B2E73,
      accentPress: 0xFF111F52,
      accent2: 0xFF9C6A19,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF070B1C,
      surface1: 0xFF10162C,
      surface2: 0xFF192344,
      fg1: 0xFFF3F4FF,
      fg2: 0xFFC7CCE5,
      fg3: 0xFF8C94B5,
      line: 0xFF2D385C,
      lineStrong: 0xFF46537B,
      accent: 0xFFE5C276,
      accentHover: 0xFFF0D99F,
      accentPress: 0xFFF8EBCB,
      accent2: 0xFF7EA6FF,
      fgOnAccent: 0xFF241A06,
    ),
    components: ThemeComponentManifest(
      controlRadius: 12,
      cardRadius: 18,
      sheetRadius: 28,
      borderWidth: 1,
      overlayElevation: 6,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFFF3F4FC, 0xFFE2E8FA, 0xFFF5E9CE],
      grainOpacity: 0.01,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF162758, 0xFF070B1C, 0xFF2A1F36],
      grainOpacity: 0.01,
    ),
  ),
  ReadendarThemeManifest(
    id: 'ocean',
    light: ThemePaletteManifest(
      bg: 0xFFEDF6F8,
      surface1: 0xFFFBFEFF,
      surface2: 0xFFDDEDF1,
      fg1: 0xFF10242A,
      fg2: 0xFF3D5860,
      fg3: 0xFF5B747B,
      line: 0xFFC4DCE1,
      lineStrong: 0xFF9EC3CC,
      accent: 0xFF1F7666,
      accentHover: 0xFF18594E,
      accentPress: 0xFF103D35,
      accent2: 0xFF5A5FBC,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF081419,
      surface1: 0xFF102128,
      surface2: 0xFF17313A,
      fg1: 0xFFEAF5F7,
      fg2: 0xFFB4CAD0,
      fg3: 0xFF7F9AA1,
      line: 0xFF27444D,
      lineStrong: 0xFF3A5D67,
      accent: 0xFF64BCAC,
      accentHover: 0xFF97D6C8,
      accentPress: 0xFFC9E9E0,
      accent2: 0xFFA8ADDD,
      fgOnAccent: 0xFF081419,
    ),
    components: ThemeComponentManifest(
      controlRadius: 12,
      cardRadius: 20,
      sheetRadius: 28,
      borderWidth: 1,
      overlayElevation: 6,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFFEDF6F8, 0xFFDDECF5],
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFF081419, 0xFF102938],
    ),
  ),
  ReadendarThemeManifest(
    id: 'noir',
    light: ThemePaletteManifest(
      bg: 0xFFF1F1EE,
      surface1: 0xFFFFFFFF,
      surface2: 0xFFE4E4E0,
      fg1: 0xFF0A0A0A,
      fg2: 0xFF3A3A3A,
      fg3: 0xFF626262,
      line: 0xFFC7C7C2,
      lineStrong: 0xFF18181A,
      accent: 0xFF18181A,
      accentHover: 0xFF2E2E2D,
      accentPress: 0xFF0A0A0A,
      accent2: 0xFF5E5E5B,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF050506,
      surface1: 0xFF121214,
      surface2: 0xFF1D1D20,
      fg1: 0xFFF7F7F5,
      fg2: 0xFFC7C7C2,
      fg3: 0xFF92928D,
      line: 0xFF343438,
      lineStrong: 0xFFEFEFEC,
      accent: 0xFFF2F2F2,
      accentHover: 0xFFFFFFFF,
      accentPress: 0xFFD9D9D5,
      accent2: 0xFFA3A39C,
      fgOnAccent: 0xFF0A0A0A,
    ),
    components: ThemeComponentManifest(
      controlRadius: 4,
      cardRadius: 4,
      sheetRadius: 12,
      borderWidth: 1.5,
      overlayElevation: 0,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.solid,
      colors: [0xFFF1F1EE],
      grainOpacity: 0.025,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.solid,
      colors: [0xFF050506],
      grainOpacity: 0.025,
    ),
  ),
  ReadendarThemeManifest(
    id: 'sapphire',
    light: ThemePaletteManifest(
      bg: 0xFFF0F4FF,
      surface1: 0xFFFCFDFF,
      surface2: 0xFFDFE7FB,
      fg1: 0xFF111B3D,
      fg2: 0xFF3D4C77,
      fg3: 0xFF61719D,
      line: 0xFFC8D3EF,
      lineStrong: 0xFF8FA3D8,
      accent: 0xFF2454C7,
      accentHover: 0xFF1A3F9B,
      accentPress: 0xFF102B70,
      accent2: 0xFFC4512C,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF070C1B,
      surface1: 0xFF10182D,
      surface2: 0xFF192643,
      fg1: 0xFFF4F7FF,
      fg2: 0xFFC1CCEA,
      fg3: 0xFF8999C3,
      line: 0xFF2B3A60,
      lineStrong: 0xFF435A8D,
      accent: 0xFF8CB4FF,
      accentHover: 0xFFABC9FF,
      accentPress: 0xFFD5E3FF,
      accent2: 0xFFFF8D68,
      fgOnAccent: 0xFF0A1734,
    ),
    components: ThemeComponentManifest(
      controlRadius: 14,
      cardRadius: 20,
      sheetRadius: 30,
      borderWidth: 1,
      overlayElevation: 6,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFFF0F4FF, 0xFFDCE8FF, 0xFFFFE8DE],
      grainOpacity: 0.01,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF102B62, 0xFF070C1B, 0xFF3B1714],
      grainOpacity: 0.01,
    ),
  ),
  ReadendarThemeManifest(
    id: 'velvet',
    light: ThemePaletteManifest(
      bg: 0xFFF8F1F5,
      surface1: 0xFFFFFBFD,
      surface2: 0xFFF0DEE8,
      fg1: 0xFF2C1321,
      fg2: 0xFF5E3B4E,
      fg3: 0xFF7B5B6D,
      line: 0xFFE1C6D4,
      lineStrong: 0xFFC49BAD,
      accent: 0xFF7B244D,
      accentHover: 0xFF5D1739,
      accentPress: 0xFF3E0D26,
      accent2: 0xFF9C672D,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF160911,
      surface1: 0xFF25101B,
      surface2: 0xFF381829,
      fg1: 0xFFFFF0F7,
      fg2: 0xFFDDBDCE,
      fg3: 0xFFA98296,
      line: 0xFF53243C,
      lineStrong: 0xFF773454,
      accent: 0xFFE8A6C5,
      accentHover: 0xFFF0C3D8,
      accentPress: 0xFFF8DFEA,
      accent2: 0xFFF0C77F,
      fgOnAccent: 0xFF321020,
    ),
    components: ThemeComponentManifest(
      controlRadius: 16,
      cardRadius: 22,
      sheetRadius: 32,
      borderWidth: 1,
      overlayElevation: 6,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFFF8F1F5, 0xFFF1DDE8, 0xFFF6E8D0],
      grainOpacity: 0.01,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF49152F, 0xFF160911, 0xFF2B1428],
      grainOpacity: 0.01,
    ),
  ),
  ReadendarThemeManifest(
    id: 'aurora',
    light: ThemePaletteManifest(
      bg: 0xFFF3F0FF,
      surface1: 0xFFFCFBFF,
      surface2: 0xFFE8E2FF,
      fg1: 0xFF1E1738,
      fg2: 0xFF51476E,
      fg3: 0xFF71658E,
      line: 0xFFD2C8F3,
      lineStrong: 0xFFB2A4E2,
      accent: 0xFF6346C7,
      accentHover: 0xFF4E35A5,
      accentPress: 0xFF39277D,
      accent2: 0xFF168B91,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF0C0B1D,
      surface1: 0xFF15142B,
      surface2: 0xFF222044,
      fg1: 0xFFF2F0FF,
      fg2: 0xFFC6C1E7,
      fg3: 0xFF938DBA,
      line: 0xFF39365F,
      lineStrong: 0xFF555184,
      accent: 0xFFA995FF,
      accentHover: 0xFFC3B7FF,
      accentPress: 0xFFDED7FF,
      accent2: 0xFF62D5D1,
      fgOnAccent: 0xFF1E1738,
    ),
    components: ThemeComponentManifest(
      controlRadius: 12,
      cardRadius: 18,
      sheetRadius: 28,
      borderWidth: 1,
      overlayElevation: 6,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFFF3F0FF, 0xFFE5F8F7, 0xFFE9DFFF],
      grainOpacity: 0.01,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFF0C0B1D, 0xFF162F3C, 0xFF2B1643],
      grainOpacity: 0.01,
    ),
  ),
  ReadendarThemeManifest(
    id: 'arcade',
    light: ThemePaletteManifest(
      bg: 0xFFF4FFD6,
      surface1: 0xFFFFFFFF,
      surface2: 0xFFE5FF7A,
      fg1: 0xFF11110E,
      fg2: 0xFF343522,
      fg3: 0xFF5A5C3D,
      line: 0xFFB7CC4B,
      lineStrong: 0xFF748300,
      accent: 0xFF4B008F,
      accentHover: 0xFF370069,
      accentPress: 0xFF26004B,
      accent2: 0xFFB80065,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF08080B,
      surface1: 0xFF111116,
      surface2: 0xFF1D1D23,
      fg1: 0xFFF5FFE0,
      fg2: 0xFFC9D7B4,
      fg3: 0xFF909B80,
      line: 0xFF3A3A42,
      lineStrong: 0xFF60606B,
      accent: 0xFFC8FF00,
      accentHover: 0xFFE0FF66,
      accentPress: 0xFFF1FFB5,
      accent2: 0xFFFF3BBA,
      fgOnAccent: 0xFF101200,
    ),
    components: ThemeComponentManifest(
      controlRadius: 0,
      cardRadius: 0,
      sheetRadius: 4,
      borderWidth: 2,
      overlayElevation: 2,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFFF4FFD6, 0xFFFFE0F2],
      grainOpacity: 0.02,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFF08080B, 0xFF260037],
      grainOpacity: 0.02,
    ),
  ),
  ReadendarThemeManifest(
    id: 'pop',
    light: ThemePaletteManifest(
      bg: 0xFFFFF4B8,
      surface1: 0xFFFFFDF4,
      surface2: 0xFFBFE8FF,
      fg1: 0xFF17143A,
      fg2: 0xFF3B365F,
      fg3: 0xFF5C5679,
      line: 0xFFD8A92E,
      lineStrong: 0xFF7B5C00,
      accent: 0xFF2447C6,
      accentHover: 0xFF19379F,
      accentPress: 0xFF102776,
      accent2: 0xFFB72E47,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF17142B,
      surface1: 0xFF211D3B,
      surface2: 0xFF332B57,
      fg1: 0xFFFFF6C7,
      fg2: 0xFFDDD1FF,
      fg3: 0xFFA79CC9,
      line: 0xFF48416A,
      lineStrong: 0xFF6C628F,
      accent: 0xFFFFD84D,
      accentHover: 0xFFFFE681,
      accentPress: 0xFFFFF1B8,
      accent2: 0xFFFF6B78,
      fgOnAccent: 0xFF241800,
    ),
    components: ThemeComponentManifest(
      controlRadius: 24,
      cardRadius: 30,
      sheetRadius: 36,
      borderWidth: 1.5,
      overlayElevation: 6,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFFFFF4B8, 0xFFFFD8E2, 0xFFCDEBFF],
      grainOpacity: 0.01,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF3B285D, 0xFF211D3B, 0xFF17142B],
      grainOpacity: 0.01,
    ),
  ),
  ReadendarThemeManifest(
    id: 'ethereal',
    isPremium: true,
    identity: ThemeIdentityManifest(
      effect: ThemeIdentityEffect.ethereal,
      fantasy: 'A living celestial manuscript shaped by the reader',
      material: 'opal light, vellum grain, and fine gold constellation ink',
      motion: 'slow orbital drift, luminous reveals, and rare meteors',
      readerReactive: true,
      nativeArtwork: true,
    ),
    light: ThemePaletteManifest(
      bg: 0xFFF4F1FF,
      surface1: 0xFFFDFCFF,
      surface2: 0xFFEAE4FF,
      fg1: 0xFF18122F,
      fg2: 0xFF4B4268,
      fg3: 0xFF70668D,
      line: 0xFFD8CEF2,
      lineStrong: 0xFFAA9ACF,
      accent: 0xFF5A3FC0,
      accentHover: 0xFF432D9C,
      accentPress: 0xFF2E1E75,
      accent2: 0xFF9A650E,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF070815,
      surface1: 0xFF111326,
      surface2: 0xFF1C203A,
      fg1: 0xFFF8F5FF,
      fg2: 0xFFD2C9EA,
      fg3: 0xFF9B90BA,
      line: 0xFF343956,
      lineStrong: 0xFF555E86,
      accent: 0xFFB6A2FF,
      accentHover: 0xFFD0C3FF,
      accentPress: 0xFFE8E1FF,
      accent2: 0xFFF2CA72,
      fgOnAccent: 0xFF1A1238,
    ),
    components: ThemeComponentManifest(
      controlRadius: 18,
      cardRadius: 24,
      sheetRadius: 34,
      borderWidth: 1,
      overlayElevation: 4,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFFF4F1FF, 0xFFDDF8FF, 0xFFFFE7F4, 0xFFFFF2CD],
      grainOpacity: 0.008,
      effect: ThemeBackgroundEffect.ethereal,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF171044, 0xFF071A2E, 0xFF2C0F33, 0xFF070815],
      grainOpacity: 0.012,
      effect: ThemeBackgroundEffect.ethereal,
    ),
  ),
  ReadendarThemeManifest(
    id: 'stormbound',
    isPremium: true,
    identity: ThemeIdentityManifest(
      effect: ThemeIdentityEffect.stormbound,
      fantasy: 'A storm-lashed academy above a volcanic dragon range',
      material:
          'black iron, scorched field maps, red wax, and violet lightning',
      motion:
          'layered cloud fronts, dense rain, sharp fractal lightning strikes, and passing wing shadows',
      readerReactive: true,
      nativeArtwork: true,
    ),
    light: ThemePaletteManifest(
      bg: 0xFFF3EFEA,
      surface1: 0xFFFFFCF8,
      surface2: 0xFFE4DDD5,
      fg1: 0xFF1D1718,
      fg2: 0xFF4D4042,
      fg3: 0xFF6E6062,
      line: 0xFFCFC3BB,
      lineStrong: 0xFF9D8B83,
      accent: 0xFF6D1A2A,
      accentHover: 0xFF53111E,
      accentPress: 0xFF380A13,
      accent2: 0xFF5C47B7,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF090A0D,
      surface1: 0xFF15171C,
      surface2: 0xFF242832,
      fg1: 0xFFF5F2F3,
      fg2: 0xFFCFC6C9,
      fg3: 0xFF9C9195,
      line: 0xFF383B44,
      lineStrong: 0xFF5A5E69,
      accent: 0xFFC5B6FF,
      accentHover: 0xFFD9D0FF,
      accentPress: 0xFFECE8FF,
      accent2: 0xFFE06672,
      fgOnAccent: 0xFF151020,
    ),
    components: ThemeComponentManifest(
      controlRadius: 8,
      cardRadius: 14,
      sheetRadius: 22,
      borderWidth: 1,
      overlayElevation: 4,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFFF3EFEA, 0xFFE5DDD8, 0xFFE7E1F5],
      grainOpacity: 0.018,
      effect: ThemeBackgroundEffect.stormbound,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF1B1F2B, 0xFF090A0D, 0xFF26101B],
      grainOpacity: 0.02,
      effect: ThemeBackgroundEffect.stormbound,
    ),
  ),
  ReadendarThemeManifest(
    id: 'evercourt',
    isPremium: true,
    identity: ThemeIdentityManifest(
      effect: ThemeIdentityEffect.evercourt,
      fantasy:
          'A sacred mountain peak beneath the three holy stars of a hidden night court',
      material:
          'faceted moonlit stone, deep indigo glass, pale silver ridges, and antique starlight',
      motion:
          'three stars breathing slowly above the peak while soft glints travel only along its outer ridge',
      readerReactive: true,
      nativeArtwork: true,
    ),
    light: ThemePaletteManifest(
      bg: 0xFFF6F2F7,
      surface1: 0xFFFFFCFF,
      surface2: 0xFFE9E1EF,
      fg1: 0xFF21182C,
      fg2: 0xFF51445F,
      fg3: 0xFF74667F,
      line: 0xFFD3C6DA,
      lineStrong: 0xFFA794B2,
      accent: 0xFF463087,
      accentHover: 0xFF352266,
      accentPress: 0xFF241747,
      accent2: 0xFF8B5812,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF080B19,
      surface1: 0xFF14182A,
      surface2: 0xFF242A46,
      fg1: 0xFFF8F4FF,
      fg2: 0xFFD5CDE3,
      fg3: 0xFF9E94B2,
      line: 0xFF373E5E,
      lineStrong: 0xFF596283,
      accent: 0xFFE5C76B,
      accentHover: 0xFFF0D98E,
      accentPress: 0xFFF8EABD,
      accent2: 0xFF9D86FF,
      fgOnAccent: 0xFF221A08,
    ),
    components: ThemeComponentManifest(
      controlRadius: 16,
      cardRadius: 22,
      sheetRadius: 32,
      borderWidth: 1,
      overlayElevation: 4,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFFF6F2F7, 0xFFE4E8F7, 0xFFF4E8D2, 0xFFECE0E8],
      grainOpacity: 0.01,
      effect: ThemeBackgroundEffect.evercourt,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF242358, 0xFF080B19, 0xFF321A2D, 0xFF0B1720],
      grainOpacity: 0.012,
      effect: ThemeBackgroundEffect.evercourt,
    ),
  ),
  ReadendarThemeManifest(
    id: 'neon_moon',
    isPremium: true,
    identity: ThemeIdentityManifest(
      effect: ThemeIdentityEffect.neonMoon,
      fantasy: 'A rain-slick magical metropolis powered by luminous gates',
      material: 'smoked glass, wet asphalt, neon tubes, and polished brass',
      motion:
          'pulsing gates, neon rain, a flickering skyline, and reflected city light',
      readerReactive: true,
      nativeArtwork: true,
    ),
    light: ThemePaletteManifest(
      bg: 0xFFF1F3F8,
      surface1: 0xFFFCFDFF,
      surface2: 0xFFE0E6F1,
      fg1: 0xFF171A2A,
      fg2: 0xFF444B63,
      fg3: 0xFF687088,
      line: 0xFFC6CEDD,
      lineStrong: 0xFF929CB2,
      accent: 0xFF8A1954,
      accentHover: 0xFF68113E,
      accentPress: 0xFF470A2A,
      accent2: 0xFF08788D,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF070914,
      surface1: 0xFF11182A,
      surface2: 0xFF1A2942,
      fg1: 0xFFF4F7FF,
      fg2: 0xFFC6D1E6,
      fg3: 0xFF8998B5,
      line: 0xFF2A3B58,
      lineStrong: 0xFF425E82,
      accent: 0xFF44D9F2,
      accentHover: 0xFF78E5F7,
      accentPress: 0xFFB0F1FA,
      accent2: 0xFFFF5BA6,
      fgOnAccent: 0xFF061A20,
    ),
    components: ThemeComponentManifest(
      controlRadius: 14,
      cardRadius: 18,
      sheetRadius: 28,
      borderWidth: 1,
      overlayElevation: 5,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFFF1F3F8, 0xFFE5F4F7, 0xFFF5E5EF],
      grainOpacity: 0.008,
      effect: ThemeBackgroundEffect.neonMoon,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF101F3D, 0xFF070914, 0xFF35102B, 0xFF081A22],
      grainOpacity: 0.014,
      effect: ThemeBackgroundEffect.neonMoon,
    ),
  ),
  ReadendarThemeManifest(
    id: 'trail',
    isPremium: true,
    identity: ThemeIdentityManifest(
      effect: ThemeIdentityEffect.trail,
      fantasy: 'An expedition route remembered through loyal tracks at dawn',
      material:
          'saddle leather, trail brass, river-blue enamel, and warm earth',
      motion:
          'large canine paw prints with subtle claws crossing in bold routes',
      readerReactive: true,
      nativeArtwork: true,
    ),
    light: ThemePaletteManifest(
      bg: 0xFFF5F1E8,
      surface1: 0xFFFFFDF8,
      surface2: 0xFFE8E0D2,
      fg1: 0xFF261D15,
      fg2: 0xFF58483B,
      fg3: 0xFF79695A,
      line: 0xFFD8CABA,
      lineStrong: 0xFFAA9580,
      accent: 0xFF7B3F18,
      accentHover: 0xFF5E2E10,
      accentPress: 0xFF421E08,
      accent2: 0xFF2D6A75,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF100C09,
      surface1: 0xFF1F1711,
      surface2: 0xFF35271D,
      fg1: 0xFFFBF5EC,
      fg2: 0xFFDCCCBD,
      fg3: 0xFFA89582,
      line: 0xFF4B382A,
      lineStrong: 0xFF74543D,
      accent: 0xFFE9A65D,
      accentHover: 0xFFF0BB7E,
      accentPress: 0xFFF6D2A7,
      accent2: 0xFF72CAD0,
      fgOnAccent: 0xFF2A1404,
    ),
    components: ThemeComponentManifest(
      controlRadius: 12,
      cardRadius: 18,
      sheetRadius: 26,
      borderWidth: 1,
      overlayElevation: 3,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFFF5F1E8, 0xFFE8E0D2, 0xFFE4EFF0, 0xFFF5E3CD],
      grainOpacity: 0.014,
      effect: ThemeBackgroundEffect.trail,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF372215, 0xFF100C09, 0xFF10292B, 0xFF20150D],
      grainOpacity: 0.018,
      effect: ThemeBackgroundEffect.trail,
    ),
  ),
  ReadendarThemeManifest(
    id: 'serpents',
    isPremium: true,
    identity: ThemeIdentityManifest(
      effect: ThemeIdentityEffect.serpents,
      fantasy: 'An obsidian sanctuary of coiling guardians and hidden paths',
      material: 'black lacquer, malachite scales, antique gold, and pale opal',
      motion:
          'sinuous headless coils, travelling scale highlights, and hypnotic rings',
      readerReactive: true,
      nativeArtwork: true,
    ),
    light: ThemePaletteManifest(
      bg: 0xFFF2F3ED,
      surface1: 0xFFFDFEF9,
      surface2: 0xFFE1E5D7,
      fg1: 0xFF18201B,
      fg2: 0xFF435146,
      fg3: 0xFF687469,
      line: 0xFFC7D0C2,
      lineStrong: 0xFF91A18F,
      accent: 0xFF175D4D,
      accentHover: 0xFF104739,
      accentPress: 0xFF0A3027,
      accent2: 0xFF8B6418,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF050A08,
      surface1: 0xFF0E1813,
      surface2: 0xFF192A21,
      fg1: 0xFFF1F8F3,
      fg2: 0xFFBED1C4,
      fg3: 0xFF879A8D,
      line: 0xFF2B4135,
      lineStrong: 0xFF476352,
      accent: 0xFFD6BE6B,
      accentHover: 0xFFE2CF8B,
      accentPress: 0xFFEEE1B2,
      accent2: 0xFF5ED6A2,
      fgOnAccent: 0xFF201A05,
    ),
    components: ThemeComponentManifest(
      controlRadius: 20,
      cardRadius: 24,
      sheetRadius: 32,
      borderWidth: 1,
      overlayElevation: 3,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFFF2F3ED, 0xFFE3E8DB, 0xFFF4E9CF, 0xFFE0E8E5],
      grainOpacity: 0.012,
      effect: ThemeBackgroundEffect.serpents,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF143629, 0xFF050A08, 0xFF2B240D, 0xFF071B17],
      grainOpacity: 0.018,
      effect: ThemeBackgroundEffect.serpents,
    ),
  ),
  ReadendarThemeManifest(
    id: 'thorn_crown',
    isPremium: true,
    identity: ThemeIdentityManifest(
      effect: ThemeIdentityEffect.thornCrown,
      fantasy:
          'A beautiful and treacherous woodland court ruled through mortal nerve',
      material:
          'moss, bone parchment, tarnished gold, oak leaves, and black thorns',
      motion:
          'interlaced vine growth, moth drift, forest light, and poison-bright glints',
      readerReactive: true,
      nativeArtwork: true,
    ),
    light: ThemePaletteManifest(
      bg: 0xFFF3F2E9,
      surface1: 0xFFFFFEF8,
      surface2: 0xFFE2E4D3,
      fg1: 0xFF1C2419,
      fg2: 0xFF485343,
      fg3: 0xFF697363,
      line: 0xFFC9CDBA,
      lineStrong: 0xFF989E84,
      accent: 0xFF3E5B2D,
      accentHover: 0xFF2E4520,
      accentPress: 0xFF1E2F14,
      accent2: 0xFF7D2D46,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF08110B,
      surface1: 0xFF121E15,
      surface2: 0xFF203024,
      fg1: 0xFFF3F6EA,
      fg2: 0xFFC9D2BC,
      fg3: 0xFF909D84,
      line: 0xFF334438,
      lineStrong: 0xFF506352,
      accent: 0xFFC5D98F,
      accentHover: 0xFFD8E6AE,
      accentPress: 0xFFEAF1D2,
      accent2: 0xFFE586A0,
      fgOnAccent: 0xFF14200D,
    ),
    components: ThemeComponentManifest(
      controlRadius: 10,
      cardRadius: 16,
      sheetRadius: 24,
      borderWidth: 1,
      overlayElevation: 3,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFFF3F2E9, 0xFFE5E9DA, 0xFFF0E4DE],
      grainOpacity: 0.02,
      effect: ThemeBackgroundEffect.thornCrown,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF1A3521, 0xFF08110B, 0xFF2A101A],
      grainOpacity: 0.022,
      effect: ThemeBackgroundEffect.thornCrown,
    ),
  ),
  ReadendarThemeManifest(
    id: 'iridescent',
    isPremium: true,
    identity: ThemeIdentityManifest(
      effect: ThemeIdentityEffect.iridescent,
      fantasy:
          'A gallery carved from black dichroic glass and structural color',
      material:
          'graphite glass, spectral cyan, hot magenta, violet, and prismatic gold',
      motion:
          'rotating dichroic facets, travelling caustics, interference contours, and spectral sweeps',
      readerReactive: true,
      nativeArtwork: true,
    ),
    light: ThemePaletteManifest(
      bg: 0xFFF0F3F4,
      surface1: 0xFFFCFEFF,
      surface2: 0xFFDFE5E8,
      fg1: 0xFF15191D,
      fg2: 0xFF424B52,
      fg3: 0xFF657078,
      line: 0xFFC6CFD4,
      lineStrong: 0xFF929FA7,
      accent: 0xFF45318D,
      accentHover: 0xFF33236D,
      accentPress: 0xFF221748,
      accent2: 0xFF087C83,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF050609,
      surface1: 0xFF101216,
      surface2: 0xFF1B1F26,
      fg1: 0xFFF5F7FA,
      fg2: 0xFFC8D0D8,
      fg3: 0xFF909BA6,
      line: 0xFF303640,
      lineStrong: 0xFF4D5663,
      accent: 0xFF70E6E0,
      accentHover: 0xFF9AEFEB,
      accentPress: 0xFFC8F8F5,
      accent2: 0xFFFF71C8,
      fgOnAccent: 0xFF071A1C,
    ),
    components: ThemeComponentManifest(
      controlRadius: 12,
      cardRadius: 18,
      sheetRadius: 26,
      borderWidth: 1,
      overlayElevation: 4,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFFF0F3F4, 0xFFE4F5F4, 0xFFF7E6F2, 0xFFEAE4F8],
      grainOpacity: 0.006,
      effect: ThemeBackgroundEffect.iridescent,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.linear,
      colors: [0xFF050609, 0xFF102A2D, 0xFF301127, 0xFF17112F, 0xFF050609],
      grainOpacity: 0.01,
      effect: ThemeBackgroundEffect.iridescent,
    ),
  ),
  ReadendarThemeManifest(
    id: 'last_light',
    isPremium: true,
    identity: ThemeIdentityManifest(
      effect: ThemeIdentityEffect.lastLight,
      fantasy:
          'A one-way science vessel carrying the last warm light toward a quiet star',
      material:
          'white ceramic, graphite instruments, amber biolight, and red stellar telemetry',
      motion:
          'star parallax, orbital packets, instrument sweeps, and live harmonic telemetry',
      readerReactive: true,
      nativeArtwork: true,
    ),
    light: ThemePaletteManifest(
      bg: 0xFFF2F5F6,
      surface1: 0xFFFFFFFF,
      surface2: 0xFFDCE5E8,
      fg1: 0xFF142027,
      fg2: 0xFF40535E,
      fg3: 0xFF637681,
      line: 0xFFC2D0D6,
      lineStrong: 0xFF8EA5AF,
      accent: 0xFF1E4D73,
      accentHover: 0xFF153A58,
      accentPress: 0xFF0D273C,
      accent2: 0xFF9A421D,
      fgOnAccent: 0xFFFFFFFF,
    ),
    dark: ThemePaletteManifest(
      bg: 0xFF05080C,
      surface1: 0xFF10161C,
      surface2: 0xFF1B252E,
      fg1: 0xFFF3F7F9,
      fg2: 0xFFC5D2D8,
      fg3: 0xFF8B9DA6,
      line: 0xFF2B3942,
      lineStrong: 0xFF465C67,
      accent: 0xFFFF735E,
      accentHover: 0xFFFF9A89,
      accentPress: 0xFFFFC5BB,
      accent2: 0xFFF4BF55,
      fgOnAccent: 0xFF240702,
    ),
    components: ThemeComponentManifest(
      controlRadius: 6,
      cardRadius: 12,
      sheetRadius: 20,
      borderWidth: 1,
      overlayElevation: 2,
    ),
    lightBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFFFFFFFF, 0xFFE6EEF1, 0xFFF5E8DE],
      grainOpacity: 0.004,
      effect: ThemeBackgroundEffect.lastLight,
    ),
    darkBackground: ThemeBackgroundManifest(
      type: ThemeBackgroundType.radial,
      colors: [0xFF172939, 0xFF05080C, 0xFF35120E],
      grainOpacity: 0.008,
      effect: ThemeBackgroundEffect.lastLight,
    ),
  ),
];
