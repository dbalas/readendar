import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/profile/appearance_sheet.dart';
import 'package:readendar/features/profile/settings_screen.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PrefsStorage> _prefs({String? theme}) async {
  SharedPreferences.setMockInitialValues({
    'theme_mode': ?theme,
  });
  return PrefsStorage(await SharedPreferences.getInstance());
}

Widget _settings(
  PrefsStorage prefs, {
  TargetPlatform platform = TargetPlatform.android,
}) => ProviderScope(
  overrides: [prefsStorageProvider.overrideWithValue(prefs)],
  child: Consumer(
    builder: (context, ref, _) {
      final themeMode = ref.watch(themeModeProvider);
      return MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme().copyWith(platform: platform),
        darkTheme: buildDarkTheme().copyWith(platform: platform),
        themeMode: themeMode,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const SettingsScreen(),
      );
    },
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final widgetCalls = <MethodCall>[];

  setUp(() {
    widgetCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          widgetCalls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('appearanceLabel and appearanceIcon cover all ThemeModes', () async {
    final l = await AppL10n.delegate.load(const Locale('es'));
    expect(appearanceLabel(l, ThemeMode.light), 'Claro');
    expect(appearanceLabel(l, ThemeMode.dark), 'Oscuro');
    expect(appearanceLabel(l, ThemeMode.system), 'Sistema');
    expect(appearanceIcon(ThemeMode.light, Brightness.dark), LucideIcons.sun);
    expect(appearanceIcon(ThemeMode.dark, Brightness.light), LucideIcons.moon);
    expect(
      appearanceIcon(ThemeMode.system, Brightness.light),
      LucideIcons.sun,
    );
    expect(
      appearanceIcon(ThemeMode.system, Brightness.dark),
      LucideIcons.moon,
    );
  });

  testWidgets('system appearance row uses sun when OS is light', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final prefs = await _prefs();
    await tester.pumpWidget(_settings(prefs));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.sun), findsOneWidget);
    expect(find.byIcon(LucideIcons.moon), findsNothing);
    expect(find.byIcon(LucideIcons.monitor), findsNothing);
  });

  testWidgets('system appearance row uses moon when OS is dark', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final prefs = await _prefs();
    await tester.pumpWidget(_settings(prefs));
    await tester.pumpAndSettle();

    expect(find.byIcon(LucideIcons.moon), findsOneWidget);
    expect(find.byIcon(LucideIcons.sun), findsNothing);
    expect(find.byIcon(LucideIcons.monitor), findsNothing);
  });

  testWidgets('settings shows current appearance and can pick System', (
    tester,
  ) async {
    final prefs = await _prefs(theme: 'dark');
    await tester.pumpWidget(_settings(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Apariencia'), findsOneWidget);
    expect(find.text('Oscuro'), findsOneWidget);

    await tester.tap(find.text('Apariencia'));
    await tester.pumpAndSettle();

    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Oscuro'), findsWidgets);
    expect(find.text('Sistema'), findsOneWidget);

    await tester.tap(find.text('Sistema'));
    await tester.pumpAndSettle();

    expect(prefs.getTheme(), 'system');
    expect(find.text('Sistema'), findsOneWidget);
  });

  testWidgets('picking Light from System persists light and pushes wdg_theme', (
    tester,
  ) async {
    final prefs = await _prefs(); // default → system
    await tester.pumpWidget(_settings(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Sistema'), findsOneWidget);

    await tester.tap(find.text('Apariencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();

    expect(prefs.getTheme(), 'light');
    expect(find.text('Claro'), findsOneWidget);

    final themeSaves = widgetCalls.where(
      (c) =>
          c.method == 'saveWidgetData' &&
          (c.arguments as Map)['id'] == kWidgetKeyTheme,
    );
    expect(themeSaves, isNotEmpty);
    expect((themeSaves.last.arguments as Map)['data'], 'light');
    // Appearance must not mint a full widget session payload.
    expect(
      widgetCalls.any(
        (c) =>
            c.method == 'saveWidgetData' &&
            (c.arguments as Map)['id'] == kWidgetKeyAccess,
      ),
      isFalse,
    );
  });

  testWidgets('picking Dark rebuilds MaterialApp into dark brightness', (
    tester,
  ) async {
    final prefs = await _prefs(theme: 'light');
    await tester.pumpWidget(_settings(prefs));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.light);

    await tester.tap(find.text('Apariencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    expect(prefs.getTheme(), 'dark');
    expect(Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark);
  });

  testWidgets('iOS appearance picker uses glass modal sheet, not action sheet', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final prefs = await _prefs(theme: 'dark');
      await tester.pumpWidget(_settings(prefs, platform: TargetPlatform.iOS));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Apariencia'));
      await tester.pumpAndSettle();

      expect(find.byType(RdGlassPanel), findsWidgets);
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('Cancelar'), findsNothing);
      expect(find.byType(RdCard), findsNothing);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Sistema'), findsOneWidget);

      await tester.tap(find.text('Sistema'));
      await tester.pumpAndSettle();
      expect(prefs.getTheme(), 'system');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
