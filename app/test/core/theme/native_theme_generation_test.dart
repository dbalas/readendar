import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native theme outputs match the canonical manifest',
    () async {
      final result = await Process.run(
        'dart',
        ['run', 'tool/generate_native_themes.dart', '--check'],
        workingDirectory: Directory.current.path,
      );

      expect(
        result.exitCode,
        0,
        reason: '${result.stdout}\n${result.stderr}',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('Ethereal native widget outputs carry static constellation artwork', () {
    final android = File(
      'android/app/src/main/res/drawable/rd_theme_ethereal_light_root.xml',
    ).readAsStringSync();
    final swift = File(
      'ios/ReadendarWidget/ReadendarWidget.swift',
    ).readAsStringSync();

    expect(android, contains('rd_theme_ethereal_artwork'));
    expect(swift, contains('EtherealWidgetArtwork'));
    expect(swift, contains('shared(Keys.appTheme) == "ethereal"'));
  });

  test('every premium identity generates Android and iOS widget artwork', () {
    const ids = [
      'stormbound',
      'evercourt',
      'neon_moon',
      'trail',
      'serpents',
      'thorn_crown',
      'iridescent',
      'last_light',
    ];
    final swift = File(
      'ios/ReadendarWidget/ReadendarWidget.swift',
    ).readAsStringSync();
    for (final id in ids) {
      final root = File(
        'android/app/src/main/res/drawable/rd_theme_${id}_light_root.xml',
      ).readAsStringSync();
      final artwork = File(
        'android/app/src/main/res/drawable/rd_theme_${id}_artwork.xml',
      );
      expect(root, contains('rd_theme_${id}_artwork'));
      expect(artwork.existsSync(), isTrue, reason: '$id Android artwork');
      expect(swift, contains('"$id"'), reason: '$id iOS artwork');
    }
    expect(swift, contains('PremiumWidgetArtwork'));
  });

  test('Storm and Courts native artwork use the rebuilt line language', () {
    final storm = File(
      'android/app/src/main/res/drawable/rd_theme_stormbound_artwork.xml',
    ).readAsStringSync();
    final courts = File(
      'android/app/src/main/res/drawable/rd_theme_evercourt_artwork.xml',
    ).readAsStringSync();

    expect(storm, isNot(contains('C92,74')));
    expect(storm, contains('L214,62'));
    expect(courts, isNot(contains('A110,110')));
    expect(courts, isNot(contains('C236,40 211,88 242,128')));
    expect(courts, contains('M18,330 L82,270 L132,294 L180,150'));
    expect(courts, isNot(contains('M180,40 L128,84 L232,84 Z')));
    expect(courts, contains('M180,58 L187,80 L180,102 L173,80 Z'));
    expect(courts, contains('M128,94 L134,112 L128,130 L122,112 Z'));
    expect(courts, contains('M232,94 L238,112 L232,130 L226,112 Z'));
  });
}
