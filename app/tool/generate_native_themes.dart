import 'dart:io';

import 'package:readendar/core/theme/theme_manifest.dart';

const _dartStart = '// GENERATED_THEME_CATALOG_START';
const _dartEnd = '// GENERATED_THEME_CATALOG_END';
const _kotlinStart = '// GENERATED_WIDGET_THEME_CATALOG_START';
const _kotlinEnd = '// GENERATED_WIDGET_THEME_CATALOG_END';
const _swiftStart = '// GENERATED_WIDGET_THEME_VALUES_START';
const _swiftEnd = '// GENERATED_WIDGET_THEME_VALUES_END';

void main(List<String> arguments) {
  final check = arguments.contains('--check');
  final appRoot = File.fromUri(Platform.script).parent.parent;
  final dartFile = File('${appRoot.path}/lib/core/theme/theme_catalog.dart');
  final kotlinFile = File(
    '${appRoot.path}/android/app/src/main/kotlin/com/readendar/readendar/ReadendarWidgetProvider.kt',
  );
  final swiftFile = File(
    '${appRoot.path}/ios/ReadendarWidget/ReadendarWidget.swift',
  );

  final mismatches = <String>[];
  _replaceGeneratedRegion(
    dartFile,
    _dartStart,
    _dartEnd,
    _dartCatalog(),
    check,
    mismatches,
    formatDart: true,
  );
  _replaceGeneratedRegion(
    swiftFile,
    _swiftStart,
    _swiftEnd,
    _swiftValues(),
    check,
    mismatches,
  );
  _replaceGeneratedRegion(
    kotlinFile,
    _kotlinStart,
    _kotlinEnd,
    _kotlinCatalog(),
    check,
    mismatches,
  );
  _writeAndroidDrawables(appRoot, check, mismatches);

  if (mismatches.isNotEmpty) {
    stderr.writeln(
      'Generated theme outputs are stale:\n${mismatches.map((e) => '  $e').join('\n')}',
    );
    exitCode = 1;
  }
}

void _replaceGeneratedRegion(
  File file,
  String start,
  String end,
  String generated,
  bool check,
  List<String> mismatches, {
  bool formatDart = false,
}) {
  final source = file.readAsStringSync();
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end);
  if (startIndex < 0 || endIndex < startIndex) {
    throw StateError('Missing generated markers in ${file.path}');
  }
  var next = source.replaceRange(
    startIndex,
    endIndex + end.length,
    '$start\n$generated\n$end',
  );
  if (formatDart) next = _formatDart(next);
  if (next == source) return;
  if (check) {
    mismatches.add(file.path);
  } else {
    file.writeAsStringSync(next);
  }
}

String _formatDart(String source) {
  final temporary = File(
    '${Directory.systemTemp.path}/readendar_theme_${DateTime.now().microsecondsSinceEpoch}.dart',
  );
  temporary.writeAsStringSync(source);
  try {
    final result = Process.runSync(Platform.resolvedExecutable, [
      'format',
      temporary.path,
    ]);
    if (result.exitCode != 0) {
      throw StateError('dart format failed: ${result.stderr}');
    }
    return temporary.readAsStringSync();
  } finally {
    temporary.deleteSync();
  }
}

String _dartCatalog() =>
    '''
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

  static final ReadendarThemeDefinition original = byId(ReadendarThemeId.original);
  static final ReadendarThemeDefinition jade = byId(ReadendarThemeId.jade);
  static final ReadendarThemeDefinition celestial = byId(ReadendarThemeId.celestial);
  static final ReadendarThemeDefinition ocean = byId(ReadendarThemeId.ocean);
  static final ReadendarThemeDefinition noir = byId(ReadendarThemeId.noir);
  static final ReadendarThemeDefinition sapphire = byId(
    ReadendarThemeId.sapphire,
  );
  static final ReadendarThemeDefinition velvet = byId(ReadendarThemeId.velvet);
  static final ReadendarThemeDefinition aurora = byId(ReadendarThemeId.aurora);
  static final ReadendarThemeDefinition arcade = byId(ReadendarThemeId.arcade);
  static final ReadendarThemeDefinition pop = byId(ReadendarThemeId.pop);
  static final ReadendarThemeDefinition ethereal = byId(ReadendarThemeId.ethereal);
  static final ReadendarThemeDefinition stormbound = byId(ReadendarThemeId.stormbound);
  static final ReadendarThemeDefinition evercourt = byId(ReadendarThemeId.evercourt);
  static final ReadendarThemeDefinition neonMoon = byId(ReadendarThemeId.neonMoon);
  static final ReadendarThemeDefinition trail = byId(ReadendarThemeId.trail);
  static final ReadendarThemeDefinition serpents = byId(ReadendarThemeId.serpents);
  static final ReadendarThemeDefinition thornCrown = byId(ReadendarThemeId.thornCrown);
  static final ReadendarThemeDefinition iridescent = byId(ReadendarThemeId.iridescent);
  static final ReadendarThemeDefinition lastLight = byId(ReadendarThemeId.lastLight);

  static ReadendarThemeDefinition byId(ReadendarThemeId id) => all.firstWhere(
    (definition) => definition.id == id,
    orElse: () => all.first,
  );

  static ReadendarThemeDefinition _fromManifest(ReadendarThemeManifest manifest) {
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

    ReadendarBackgroundTreatment background(ThemeBackgroundManifest value) =>
        ReadendarBackgroundTreatment(
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
            ThemeBackgroundEffect.stormbound => ReadendarBackgroundEffect.stormbound,
            ThemeBackgroundEffect.evercourt => ReadendarBackgroundEffect.evercourt,
            ThemeBackgroundEffect.neonMoon => ReadendarBackgroundEffect.neonMoon,
            ThemeBackgroundEffect.trail => ReadendarBackgroundEffect.trail,
            ThemeBackgroundEffect.serpents => ReadendarBackgroundEffect.serpents,
            ThemeBackgroundEffect.thornCrown => ReadendarBackgroundEffect.thornCrown,
            ThemeBackgroundEffect.iridescent => ReadendarBackgroundEffect.iridescent,
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
'''
        .trim();

String _kotlinCatalog() {
  final palettes = <String>[];
  final resources = <String>[];
  for (final theme in readendarThemeManifest) {
    palettes.add(
      '        "${theme.id}" to Palette(${_kotlinPalette(theme.light)}, ${_kotlinPalette(theme.dark)})',
    );
    for (final dark in [false, true]) {
      final mode = dark ? 'dark' : 'light';
      final prefix = 'rd_theme_${theme.id}_$mode';
      resources.add(
        '        "${theme.id}_$mode" to WResources(R.drawable.${prefix}_root, R.drawable.${prefix}_surface, R.drawable.${prefix}_control, R.drawable.${prefix}_button)',
      );
    }
  }
  return '''
    data class WColors(
        val bg: Int,
        val surface: Int,
        val surface2: Int,
        val primary: Int,
        val secondary: Int,
        val line: Int,
        val lineStrong: Int,
        val accent: Int,
        val accent2: Int,
        val onAccent: Int,
    )

    data class WResources(
        val root: Int,
        val surface: Int,
        val control: Int,
        val button: Int,
    )

    private data class Palette(val light: Array<String>, val dark: Array<String>)

    private val palettes = mapOf(
${palettes.join(',\n')},
    )

    private val resources = mapOf(
${resources.join(',\n')},
    )
'''
      .trimRight();
}

String _swiftValues() {
  final cases = <String>[];
  for (final theme in readendarThemeManifest) {
    for (final entry in <(bool, ThemePaletteManifest, ThemeBackgroundManifest)>[
      (false, theme.light, theme.lightBackground),
      (true, theme.dark, theme.darkBackground),
    ]) {
      final palette = entry.$2;
      final background = entry.$3;
      cases.add(
        '        case ("${theme.id}", ${entry.$1}): ${_swiftValue(theme, palette, background)}',
      );
    }
  }
  return '''
        let values: Values = switch (id, dark) {
${cases.join('\n')}
        default: ${_swiftValue(readendarThemeManifest.first, readendarThemeManifest.first.light, readendarThemeManifest.first.lightBackground)}
        }
'''
      .trimRight();
}

String _swiftValue(
  ReadendarThemeManifest theme,
  ThemePaletteManifest palette,
  ThemeBackgroundManifest background,
) {
  final colors = background.colors
      .map(
        (color) =>
            '0x${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
      )
      .join(', ');
  String rgb(int color) =>
      '0x${(color & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  return 'Values(background: [$colors], backgroundKind: "${background.type.name}", '
      'surface: ${rgb(palette.surface1)}, surface2: ${rgb(palette.surface2)}, '
      'primary: ${rgb(palette.fg1)}, secondary: ${rgb(palette.fg3)}, '
      'line: ${rgb(palette.line)}, lineStrong: ${rgb(palette.lineStrong)}, '
      'accent: ${rgb(palette.accent)}, accent2: ${rgb(palette.accent2)}, '
      'onAccent: ${rgb(palette.fgOnAccent)}, controlRadius: ${_number(theme.components.controlRadius)}, '
      'cardRadius: ${_number(theme.components.cardRadius)}, borderWidth: ${_number(theme.components.borderWidth)})';
}

String _kotlinPalette(ThemePaletteManifest p) =>
    'arrayOf(${[
      p.bg,
      p.surface1,
      p.surface2,
      p.fg1,
      p.fg3,
      p.line,
      p.lineStrong,
      p.accent,
      p.accent2,
      p.fgOnAccent,
    ].map((color) => '"${_hex(color)}"').join(', ')})';

void _writeAndroidDrawables(
  Directory appRoot,
  bool check,
  List<String> mismatches,
) {
  final directory = Directory(
    '${appRoot.path}/android/app/src/main/res/drawable',
  );
  final expectedFiles = <String>{};
  for (final theme in readendarThemeManifest) {
    for (final entry
        in <(String, ThemePaletteManifest, ThemeBackgroundManifest)>[
          ('light', theme.light, theme.lightBackground),
          ('dark', theme.dark, theme.darkBackground),
        ]) {
      final mode = entry.$1;
      final palette = entry.$2;
      final background = entry.$3;
      final prefix = 'rd_theme_${theme.id}_$mode';
      final outputs = <String, String>{
        '${prefix}_root.xml': _androidRoot(
          theme.id,
          theme.identity,
          background,
          theme.components.cardRadius,
        ),
        '${prefix}_surface.xml': _androidShape(
          palette.surface1,
          palette.line,
          theme.components.cardRadius,
          theme.components.borderWidth,
        ),
        '${prefix}_control.xml': _androidShape(
          palette.surface2,
          palette.lineStrong,
          theme.components.controlRadius,
          theme.components.borderWidth,
        ),
        '${prefix}_button.xml': _androidShape(
          palette.accent,
          palette.accent,
          theme.components.controlRadius,
          0,
        ),
      };
      if (theme.identity.nativeArtwork) {
        final artworkName = 'rd_theme_${theme.id}_artwork.xml';
        expectedFiles.add(artworkName);
        final artworkFile = File('${directory.path}/$artworkName');
        final artwork = '${_androidIdentityArtwork(theme).trim()}\n';
        if (!artworkFile.existsSync() ||
            artworkFile.readAsStringSync() != artwork) {
          if (check) {
            mismatches.add(artworkFile.path);
          } else {
            artworkFile.writeAsStringSync(artwork);
          }
        }
      }
      for (final output in outputs.entries) {
        expectedFiles.add(output.key);
        final file = File('${directory.path}/${output.key}');
        final content = '${output.value.trim()}\n';
        if (file.existsSync() && file.readAsStringSync() == content) continue;
        if (check) {
          mismatches.add(file.path);
        } else {
          file.writeAsStringSync(content);
        }
      }
    }
  }
  for (final entity in directory.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.startsWith('rd_theme_') ||
        !name.endsWith('.xml') ||
        expectedFiles.contains(name)) {
      continue;
    }
    if (check) {
      mismatches.add(entity.path);
    } else {
      entity.deleteSync();
    }
  }
}

String _androidRoot(
  String id,
  ThemeIdentityManifest identity,
  ThemeBackgroundManifest background,
  double radius,
) {
  final colors = background.colors;
  final fill = switch (background.type) {
    ThemeBackgroundType.solid =>
      '<solid android:color="${_hex(colors.first)}" />',
    ThemeBackgroundType.linear =>
      '<gradient android:angle="315" android:startColor="${_hex(colors.first)}" android:endColor="${_hex(colors.last)}" />',
    ThemeBackgroundType.radial =>
      '<gradient android:type="radial" android:gradientRadius="420dp" android:centerX="0.45" android:centerY="0.25" android:startColor="${_hex(colors.first)}" android:endColor="${_hex(colors.last)}" />',
  };
  final shape =
      '''
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    $fill
    <corners android:radius="${_number(radius)}dp" />
</shape>
''';
  if (!identity.nativeArtwork) {
    return '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_native_themes.dart. -->
$shape
''';
  }
  return '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_native_themes.dart. -->
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>$shape</item>
    <item android:drawable="@drawable/rd_theme_${id}_artwork" />
</layer-list>
''';
}

const _androidEtherealArtwork = '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_native_themes.dart. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="360dp"
    android:height="360dp"
    android:viewportWidth="360"
    android:viewportHeight="360">
    <path
        android:fillColor="#00FFFFFF"
        android:strokeColor="#4DF2CA72"
        android:strokeWidth="1"
        android:pathData="M24,74 L82,42 L134,88 L205,54 M248,118 L302,82 L334,138 M42,248 L96,214 L148,262 L220,226 L314,286" />
    <path
        android:fillColor="#59FFFFFF"
        android:pathData="M20,70 L28,70 L28,78 L20,78 Z M78,38 L86,38 L86,46 L78,46 Z M130,84 L138,84 L138,92 L130,92 Z M201,50 L209,50 L209,58 L201,58 Z M244,114 L252,114 L252,122 L244,122 Z M298,78 L306,78 L306,86 L298,86 Z M330,134 L338,134 L338,142 L330,142 Z M38,244 L46,244 L46,252 L38,252 Z M92,210 L100,210 L100,218 L92,218 Z M144,258 L152,258 L152,266 L144,266 Z M216,222 L224,222 L224,230 L216,230 Z M310,282 L318,282 L318,290 L310,290 Z" />
</vector>
''';

String _androidIdentityArtwork(ReadendarThemeManifest theme) {
  if (theme.identity.effect == ThemeIdentityEffect.ethereal) {
    return _androidEtherealArtwork;
  }
  if (theme.identity.effect == ThemeIdentityEffect.trail) {
    return _androidFootprintArtwork(
      theme,
      canine: true,
    );
  }
  if (theme.identity.effect == ThemeIdentityEffect.evercourt) {
    return _androidVelarisArtwork(theme);
  }
  final path = switch (theme.identity.effect) {
    ThemeIdentityEffect.stormbound =>
      'M230,-10 L214,62 L224,68 L192,128 L202,135 L166,208 L177,214 L130,350 M192,128 L148,186 L158,192 L128,246 M166,208 L222,266 L214,274 L250,328',
    ThemeIdentityEffect.evercourt => '',
    ThemeIdentityEffect.neonMoon =>
      'M76,300 L76,184 A104,104 0,0 1,284,184 L284,300 M48,318 L312,318 M210,58 A64,64 0,1 0,276,126 A54,54 0,0 1,210,58',
    ThemeIdentityEffect.serpents =>
      'M42,286 C112,196 236,330 314,232 C364,170 288,106 216,152 C142,200 126,92 210,54 C286,20 330,68 314,116',
    ThemeIdentityEffect.thornCrown =>
      'M20,254 C72,174 124,290 178,202 C232,114 274,244 340,142 M72,208 L52,178 M116,238 L136,202 M190,188 L170,154 M244,174 L266,142 M302,174 L286,132',
    ThemeIdentityEffect.iridescent =>
      'M42,332 L144,20 M116,340 L218,18 M202,340 L304,28 M280,338 L346,132',
    ThemeIdentityEffect.lastLight =>
      'M238,72 A78,78 0,1 1,237,72 M238,72 A126,126 0,0 1,330,278 M28,282 L88,282 L102,242 L122,318 L146,282 L196,282',
    ThemeIdentityEffect.none ||
    ThemeIdentityEffect.ethereal ||
    ThemeIdentityEffect.trail => '',
  };
  final accent = _hex((0x4D << 24) | (theme.light.accent & 0xFFFFFF));
  final accent2 = _hex((0x3D << 24) | (theme.light.accent2 & 0xFFFFFF));
  const detailPath =
      'M32,66 a3,3 0,1 0,6 0 a3,3 0,1 0,-6 0 M320,92 a3,3 0,1 0,6 0 a3,3 0,1 0,-6 0 M286,304 a3,3 0,1 0,6 0 a3,3 0,1 0,-6 0';
  return '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_native_themes.dart. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="360dp"
    android:height="360dp"
    android:viewportWidth="360"
    android:viewportHeight="360">
    <path
        android:fillColor="#00FFFFFF"
        android:strokeColor="$accent"
        android:strokeWidth="1.2"
        android:strokeLineCap="round"
        android:strokeLineJoin="round"
        android:pathData="$path" />
    <path
        android:fillColor="$accent2"
        android:pathData="$detailPath" />
</vector>
''';
}

String _androidVelarisArtwork(ReadendarThemeManifest theme) {
  final accent = _hex((0x54 << 24) | (theme.light.accent & 0xFFFFFF));
  final accent2 = _hex((0x4A << 24) | (theme.light.accent2 & 0xFFFFFF));
  final mountain = _hex((0x24 << 24) | (theme.light.accent & 0xFFFFFF));
  return '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_native_themes.dart. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="360dp"
    android:height="360dp"
    android:viewportWidth="360"
    android:viewportHeight="360">
    <path
        android:fillColor="$mountain"
        android:pathData="M-12,360 L18,330 L82,270 L132,294 L180,150 L228,270 L274,220 L372,330 L372,372 L-12,372 Z" />
    <path
        android:fillColor="#00FFFFFF"
        android:strokeColor="$accent"
        android:strokeWidth="1.35"
        android:strokeLineCap="round"
        android:strokeLineJoin="round"
        android:pathData="M18,330 L82,270 L132,294 L180,150 L228,270 L274,220 L342,330" />
    <path
        android:fillColor="$accent2"
        android:pathData="M180,58 L187,80 L180,102 L173,80 Z M158,80 L180,75 L202,80 L180,85 Z M128,94 L134,112 L128,130 L122,112 Z M112,112 L128,108 L144,112 L128,116 Z M232,94 L238,112 L232,130 L226,112 Z M216,112 L232,108 L248,112 L232,116 Z" />
</vector>
''';
}

String _androidFootprintArtwork(
  ReadendarThemeManifest theme, {
  required bool canine,
}) {
  final centers = canine
      ? const <(double, double)>[
          (42, 302),
          (102, 250),
          (164, 204),
          (228, 152),
          (298, 98),
        ]
      : const <(double, double)>[
          (48, 282),
          (96, 226),
          (148, 178),
          (206, 134),
          (270, 88),
          (322, 44),
        ];
  final radius = canine ? 10.0 : 7.0;
  final pads = StringBuffer();
  final toes = StringBuffer();
  final claws = StringBuffer();
  for (final (centerX, centerY) in centers) {
    final padY = centerY + radius * 0.45;
    pads.write(
      'M${_number(centerX - radius)} ${_number(padY)} '
      'a${_number(radius)},${_number(radius * 0.78)} 0,1 0,${_number(radius * 2)},0 '
      'a${_number(radius)},${_number(radius * 0.78)} 0,1 0,-${_number(radius * 2)},0 ',
    );
    for (var toe = 0; toe < 4; toe++) {
      final toeX = centerX + (toe - 1.5) * radius * 0.72;
      final toeY = centerY - radius * (0.48 + (toe == 1 || toe == 2 ? 0.2 : 0));
      final toeRadius = radius * (canine ? 0.3 : 0.33);
      toes.write(
        'M${_number(toeX - toeRadius)},${_number(toeY)} '
        'a${_number(toeRadius)},${_number(toeRadius)} 0,1 0,${_number(toeRadius * 2)},0 '
        'a${_number(toeRadius)},${_number(toeRadius)} 0,1 0,-${_number(toeRadius * 2)},0 ',
      );
      if (canine) {
        claws.write(
          'M${_number(toeX)},${_number(toeY - toeRadius * 1.25)} '
          'L${_number(toeX)},${_number(toeY - toeRadius * 2.05)} ',
        );
      }
    }
  }
  final accent = _hex((0x52 << 24) | (theme.light.accent & 0xFFFFFF));
  final accent2 = _hex((0x47 << 24) | (theme.light.accent2 & 0xFFFFFF));
  return '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_native_themes.dart. -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="360dp"
    android:height="360dp"
    android:viewportWidth="360"
    android:viewportHeight="360">
    <path android:fillColor="$accent" android:pathData="$pads" />
    <path android:fillColor="$accent2" android:pathData="$toes" />
    ${canine ? '<path android:fillColor="#00FFFFFF" android:strokeColor="$accent2" android:strokeWidth="1.2" android:strokeLineCap="round" android:pathData="$claws" />' : ''}
</vector>
''';
}

String _androidShape(int fill, int stroke, double radius, double width) =>
    '''
<?xml version="1.0" encoding="utf-8"?>
<!-- Generated by tool/generate_native_themes.dart. -->
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="${_hex(fill)}" />
    ${width > 0 ? '<stroke android:width="${_number(width)}dp" android:color="${_hex(stroke)}" />' : ''}
    <corners android:radius="${_number(radius)}dp" />
</shape>
''';

String _hex(int color) =>
    '#${color.toRadixString(16).padLeft(8, '0').toUpperCase()}';

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();
