import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/profile/app_behavior_settings_screen.dart';
import 'package:readendar/features/profile/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUser _user({bool autoCreate = false, bool showSpoilers = false}) => AppUser(
  id: 'user-1',
  email: 'reader@example.com',
  displayName: 'Reader',
  preferredLocale: 'es',
  timezone: 'Europe/Madrid',
  onboardingCompletedAt: DateTime.utc(2026, 1, 2),
  autoCreateStatusEvents: autoCreate,
  alwaysShowSpoilerQuotes: showSpoilers,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (call) async => true,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  testWidgets('settings links to app behavior screen', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionProvider.overrideWith((ref) {
            final n = SessionNotifier(ref)..setUser(_user());
            return n;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Comportamiento'), findsOneWidget);
    expect(find.text('Eventos al cambiar estado'), findsNothing);

    await tester.tap(find.text('Comportamiento'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBehaviorSettingsScreen), findsOneWidget);
    expect(find.text('Eventos al cambiar estado'), findsWidgets);
    expect(find.textContaining('inicio'), findsWidgets);
    expect(find.textContaining('fin'), findsWidgets);
  });

  testWidgets('behavior preference titles never truncate', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionProvider.overrideWith((ref) {
            return SessionNotifier(ref)..setUser(_user());
          }),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const AppBehaviorSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final title in [
      'Eventos al cambiar estado',
    ]) {
      // Large text scale can push the second card offstage; truncation
      // rules still apply to the Text config whether painted or not.
      final text = tester.widgetList<Text>(
        find.text(title, skipOffstage: false),
      ).first;
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('behavior screen persists auto status events locally', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    late SessionNotifier session;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionProvider.overrideWith((ref) {
            return session = SessionNotifier(ref)..setUser(_user());
          }),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const AppBehaviorSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sw = tester.widgetList<Switch>(
      find.byKey(const Key('autoStatusEventsSwitch')),
    ).first;
    expect(sw.value, isFalse);

    sw.onChanged!(true);
    await tester.pumpAndSettle();

    expect(session.state.user?.autoCreateStatusEvents, isTrue);
    expect(
      tester
          .widgetList<Switch>(find.byKey(const Key('autoStatusEventsSwitch')))
          .first
          .value,
      isTrue,
    );
    expect(find.byType(SnackBar), findsOneWidget);
    final stored = PrefsStorage(prefs).getLocalProfileJson();
    expect(stored, contains('"autoCreateStatusEvents":true'));
  });

  testWidgets('behavior screen rolls back and toasts when persist fails', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    late _ThrowingSession session;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionProvider.overrideWith((ref) {
            return session = _ThrowingSession(ref)..setUser(_user());
          }),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const AppBehaviorSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widgetList<Switch>(find.byKey(const Key('autoStatusEventsSwitch')))
        .first
        .onChanged!(true);
    await tester.pumpAndSettle();

    expect(session.state.user?.autoCreateStatusEvents, isFalse);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
    'saving a preference disables only that switch',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final gate = Completer<void>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionProvider.overrideWith((ref) {
              return _GatedSession(ref, gate)..setUser(_user());
            }),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const AppBehaviorSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .widgetList<Switch>(find.byKey(const Key('autoStatusEventsSwitch')))
          .first
          .onChanged!(true);
      await tester.pump();

      expect(
        tester
            .widgetList<Switch>(find.byKey(const Key('autoStatusEventsSwitch')))
            .first
            .onChanged,
        isNull,
        reason: 'active switch disables only itself while saving',
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<Switch>(find.byKey(const Key('autoStatusEventsSwitch')))
            .first
            .onChanged,
        isNotNull,
      );
    },
  );
}

class _ThrowingSession extends SessionNotifier {
  _ThrowingSession(super.ref);

  @override
  Future<void> persistLocalUser(AppUser user) async {
    throw StateError('disk');
  }
}

class _GatedSession extends SessionNotifier {
  _GatedSession(super.ref, this.gate);
  final Completer<void> gate;

  @override
  Future<void> persistLocalUser(AppUser user) async {
    await gate.future;
    await super.persistLocalUser(user);
  }
}
