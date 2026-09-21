import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/rd_context_menu.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_menu.dart';

ThemeData _iosTheme() =>
    buildLightTheme().copyWith(platform: TargetPlatform.iOS);

ThemeData _androidTheme() =>
    buildLightTheme().copyWith(platform: TargetPlatform.android);

Future<void> _withIosPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('rdFloatingNavContentInset is shared across platforms', (
    tester,
  ) async {
    late double inset;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Theme(
          data: _iosTheme(),
          child: Builder(
            builder: (context) {
              inset = rdFloatingNavContentInset(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(inset, RdRootNavBarMetrics.contentInset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Theme(
          data: _androidTheme(),
          child: Builder(
            builder: (context) {
              inset = rdFloatingNavContentInset(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(inset, RdRootNavBarMetrics.contentInset);
  });

  testWidgets(
    'rdFloatingNavContentInset includes system viewPadding under extendBody',
    (tester) async {
      late double inset;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 34),
            viewPadding: EdgeInsets.only(bottom: 34),
          ),
          child: Theme(
            data: _iosTheme(),
            child: Builder(
              builder: (context) {
                inset = rdFloatingNavContentInset(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(inset, RdRootNavBarMetrics.contentInset + 34);
    },
  );

  testWidgets('RdGlassPanel can skip BackdropFilter', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _iosTheme(),
          home: const Scaffold(
            body: RdGlassPanel(
              blur: false,
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });

  testWidgets('RdGlassPanel uses Cupertino action-sheet fill', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _iosTheme(),
          home: const Scaffold(
            body: RdGlassPanel(child: SizedBox(width: 40, height: 40)),
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(RdGlassPanel.blurSigma, CupertinoPopupSurface.defaultBlurSigma);
      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(RdGlassPanel),
          matching: find.byType(ColoredBox),
        ),
      );
      // Cupertino action-sheet material (not denser dialog gray).
      expect(fill.color, const Color(0xC8FCFCFC));
    });
  });

  testWidgets('RdGlassPanel uses dark Cupertino action-sheet fill', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            platform: TargetPlatform.iOS,
          ),
          home: const Scaffold(
            body: RdGlassPanel(child: SizedBox(width: 40, height: 40)),
          ),
        ),
      );
      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(RdGlassPanel),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(fill.color, const Color(0xBE292929));
    });
  });

  testWidgets('RdGlassPanel cancel plate is opaque without blur', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: _iosTheme(),
          home: const Scaffold(
            body: RdGlassPanel(
              blur: false,
              child: SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(RdGlassPanel),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(fill.color, const Color(0xFFFFFFFF));
    });
  });

  testWidgets('RdContextMenu uses CupertinoContextMenu on iOS', (tester) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          theme: _iosTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: RdContextMenu(
              items: const [
                RdMenuItem(value: 'edit', label: 'Edit'),
              ],
              onSelected: (_) {},
              child: const Text('Quote body'),
            ),
          ),
        ),
      );
      expect(find.byType(CupertinoContextMenu), findsOneWidget);
    });
  });

  test('features must not call showModalBottomSheet directly', () {
    final root = Directory('${Directory.current.path}/lib/features');
    expect(root.existsSync(), isTrue, reason: 'run from app/');
    final offenders = <String>[];
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      if (text.contains('showModalBottomSheet')) {
        offenders.add(file.path.replaceFirst('${Directory.current.path}/', ''));
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use showRdModalSheet / showRdMenu instead:\n'
          '${offenders.join('\n')}',
    );
  });

  test('features must not use Material PopupMenuButton', () {
    final root = Directory('${Directory.current.path}/lib/features');
    expect(root.existsSync(), isTrue, reason: 'run from app/');
    final offenders = <String>[];
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      if (text.contains('PopupMenuButton')) {
        offenders.add(file.path.replaceFirst('${Directory.current.path}/', ''));
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use RdOverflowMenu / showRdMenu so iOS keeps glass chrome:\n'
          '${offenders.join('\n')}',
    );
  });

  test('features must not call showRdGlassActionSheet directly', () {
    final root = Directory('${Directory.current.path}/lib/features');
    expect(root.existsSync(), isTrue, reason: 'run from app/');
    final offenders = <String>[];
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      if (text.contains('showRdGlassActionSheet')) {
        offenders.add(file.path.replaceFirst('${Directory.current.path}/', ''));
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Choice menus use showRdMenu; destination lists use showRdNavSheet:\n'
          '${offenders.join('\n')}',
    );
  });
}
