import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/theme_preview_card.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/di/theme_selection.dart';
import 'package:readendar/features/profile/premium_themes_screen.dart';
import 'package:readendar/features/profile/themes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('selecting a theme persists it and marks it selected', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(tester, preferences: preferences);

    expect(find.text('Original'), findsWidgets);
    expect(find.text('Jade'), findsWidgets);
    await tester.tap(find.text('Jade').first);
    await tester.pumpAndSettle();

    expect(preferences.getString('theme_preset'), 'jade');
    expect(find.text('Tema aplicado.'), findsOneWidget);
  });

  testWidgets('persistence failure keeps selection and shows localized error', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(
      tester,
      preferences: preferences,
      overrides: [
        themePreferenceWriterProvider.overrideWithValue((_) async => false),
      ],
    );

    await tester.tap(find.text('Jade').first);
    await tester.pumpAndSettle();

    expect(preferences.getString('theme_preset'), isNull);
    expect(find.text('No se pudo guardar el tema.'), findsOneWidget);
  });

  testWidgets('native widget failure reports partial success', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(
      tester,
      preferences: preferences,
      overrides: [
        widgetThemeWriterProvider.overrideWithValue((_) async => false),
      ],
    );

    await tester.tap(find.text('Jade').first);
    await tester.pumpAndSettle();

    expect(preferences.getString('theme_preset'), 'jade');
    expect(
      find.text('Tema aplicado, pero no se pudieron actualizar los widgets.'),
      findsOneWidget,
    );
  });

  testWidgets('pending selection shows progress and disables every choice', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final pending = Completer<bool>();
    await _pump(
      tester,
      preferences: preferences,
      overrides: [
        themePreferenceWriterProvider.overrideWithValue((_) => pending.future),
      ],
    );

    await tester.tap(find.text('Jade').first);
    await tester.pump();

    expect(find.byType(RdProgress), findsOneWidget);
    final cards = tester.widgetList<ThemePreviewCard>(
      find.byType(ThemePreviewCard),
    );
    expect(cards, isNotEmpty);
    expect(cards.every((card) => !card.enabled), isTrue);

    pending.complete(false);
    await tester.pumpAndSettle();
  });

  testWidgets('theme cards use Cupertino interaction on Apple platforms', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(
      tester,
      preferences: preferences,
      platform: TargetPlatform.iOS,
    );

    expect(find.byType(CupertinoButton), findsWidgets);
  });

  testWidgets('premium collection entry is always available', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(tester, preferences: preferences);
    expect(find.byKey(const Key('premiumThemesEntry')), findsOneWidget);
    expect(find.text('Temas Premium'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('premiumThemesEntry')),
        matching: find.byType(ThemePreviewCard),
      ),
      findsNothing,
    );
  });

  testWidgets('premium entry opens collection and applies Ethereal', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(tester, preferences: preferences);

    await tester.tap(find.byKey(const Key('premiumThemesEntry')));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumThemesScreen), findsOneWidget);
    expect(find.text('Etéreo'), findsOneWidget);
    expect(find.text('Premium collection'), findsNothing);

    final premiumCard = tester
        .widgetList<ThemePreviewCard>(
          find.byType(ThemePreviewCard),
        )
        .first;
    expect(premiumCard.previewHeight, 132);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.tap(find.text('Etéreo'));
    await tester.pumpAndSettle();
    expect(preferences.getString('theme_preset'), 'ethereal');
    expect(find.text('Tema aplicado.'), findsOneWidget);
  });

  testWidgets('deep premium identity persists its canonical wire ID', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(
      tester,
      preferences: preferences,
      home: const PremiumThemesScreen(),
    );

    final lastLight = find.text('Sol');
    await tester.dragUntilVisible(
      lastLight,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(lastLight);
    await tester.pumpAndSettle();
    await tester.tap(lastLight);
    await tester.pumpAndSettle();

    expect(preferences.getString('theme_preset'), 'last_light');
    expect(find.text('Tema aplicado.'), findsOneWidget);
  });

  testWidgets('removed Whisper stays hidden and Trail persists', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(
      tester,
      preferences: preferences,
      home: const PremiumThemesScreen(),
    );

    expect(find.text('Ember'), findsNothing);
    expect(find.text('Cats'), findsNothing);
    expect(find.text('Dogs'), findsNothing);
    expect(find.text('Whisper'), findsNothing);
    for (final label in ['Rastro', 'Serpientes']) {
      final animal = find.text(label);
      await tester.dragUntilVisible(
        animal,
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.ensureVisible(animal);
      await tester.pumpAndSettle();
      expect(animal, findsOneWidget);
    }
    final trail = find.text('Rastro');
    await tester.dragUntilVisible(
      trail,
      find.byType(ListView),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    await tester.tap(trail);
    await tester.pumpAndSettle();

    expect(preferences.getString('theme_preset'), 'trail');
    expect(find.text('Tema aplicado.'), findsOneWidget);
  });

  testWidgets('cover-led atmosphere is opt-in and persists locally', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(
      tester,
      preferences: preferences,
      home: const PremiumThemesScreen(),
    );

    final toggle = find.byKey(const Key('premiumCoverAtmosphereToggle'));
    await tester.dragUntilVisible(
      toggle,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(preferences.getBool('premium_cover_atmosphere'), isTrue);
  });

  testWidgets('cover-led atmosphere reports persistence failure', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(
      tester,
      preferences: preferences,
      home: const PremiumThemesScreen(),
      overrides: [
        premiumCoverAtmosphereWriterProvider.overrideWithValue(
          (_) async => false,
        ),
      ],
    );

    final toggle = find.byKey(const Key('premiumCoverAtmosphereToggle'));
    await tester.dragUntilVisible(
      toggle,
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(preferences.getBool('premium_cover_atmosphere'), isNull);
    expect(
      find.text('No se pudo guardar la preferencia de atmósfera de portada.'),
      findsOneWidget,
    );
  });

  testWidgets('premium screen stays available without premium entitlement', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await _pump(
      tester,
      preferences: preferences,
      home: const PremiumThemesScreen(),
    );

    expect(find.text('Etéreo'), findsOneWidget);
    expect(
      find.text('Este tema Premium no está disponible en esta instalación.'),
      findsNothing,
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required SharedPreferences preferences,
  TargetPlatform platform = TargetPlatform.android,
  List<Override> overrides = const [],
  Widget home = const ThemesScreen(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(home.runtimeType),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        sessionProvider.overrideWith((ref) {
          final notifier = _TestSession(ref);
          notifier.force(_user());
          return notifier;
        }),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: ThemeData(platform: platform),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
}

AppUser _user() => AppUser(
  id: 'user-1',
  email: 'reader@example.com',
  displayName: 'Reader',
  preferredLocale: 'es',
  timezone: 'Europe/Madrid',
  onboardingCompletedAt: DateTime(2026),
);

class _TestSession extends SessionNotifier {
  _TestSession(super.ref);

  void force(AppUser user) => state = SessionState(user: user);
}
