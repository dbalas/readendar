import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/features/onboarding/onboarding_tour_screen.dart';

void main() {
  Widget wrap(VoidCallback onFinish, {ThemeData? theme}) => MaterialApp(
    locale: const Locale('es'),
    theme: theme,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: OnboardingTourScreen(onFinish: onFinish),
  );

  AppL10n l10n(WidgetTester tester) =>
      AppL10n.of(tester.element(find.byType(OnboardingTourScreen)));

  // The heroes run endless ambient animations, so pumpAndSettle would hang.
  // Settle page transitions with explicit pumps instead.

  // Deterministic advance via the "Siguiente" button (programmatic page scroll).
  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('renders the welcome slide with skip and next controls', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(() {}));
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('Bienvenido a Readendar'), findsOneWidget);
    expect(find.text('Saltar'), findsOneWidget);
    expect(find.text('Siguiente'), findsOneWidget);
    expect(find.text('Empezar'), findsNothing);
  });

  testWidgets('uses default scaffold background like other gate screens', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(() {}));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, isNull);
  });

  testWidgets('Skip invokes onFinish', (tester) async {
    var finished = false;
    await tester.pumpWidget(wrap(() => finished = true));
    await tester.pump(const Duration(milliseconds: 1000));

    await tester.tap(find.text('Saltar'));
    await tester.pump();

    expect(finished, isTrue);
  });

  testWidgets('swiping advances to the next feature slide', (tester) async {
    await tester.pumpWidget(wrap(() {}));
    await tester.pump(const Duration(milliseconds: 1000));

    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Welcome → Library is the first advance in the renewed lineup.
    expect(find.text('Trae tu biblioteca'), findsOneWidget);
    expect(
      find.text(
        'Importa tu biblioteca desde tus aplicaciones de lectura en segundos.',
      ),
      findsOneWidget,
    );
    expect(find.text('Siguiente'), findsOneWidget);
  });

  testWidgets('quotes slide follows the calendar', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(() {}));
    await tester.pump(const Duration(milliseconds: 1000));
    final l = l10n(tester);

    for (var i = 0; i < 4; i++) {
      await tapNext(tester);
    }

    expect(find.text(l.tourQuotesTitle), findsOneWidget);
    expect(find.text(l.tourQuotesSubtitle), findsOneWidget);
  });

  testWidgets('quotes hero renders without overflow in dark mode', (
    tester,
  ) async {
    FlutterErrorDetails? overflow;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) {
        overflow = details;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(wrap(() {}, theme: buildDarkTheme()));
    await tester.pump(const Duration(milliseconds: 1000));

    for (var i = 0; i < 4; i++) {
      await tapNext(tester);
    }
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.byIcon(LucideIcons.quote), findsWidgets);
    expect(overflow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('last slide shows Get started and finishes', (tester) async {
    var finished = false;
    await tester.pumpWidget(wrap(() => finished = true));
    await tester.pump(const Duration(milliseconds: 1000));

    // Six slides: five advances land on the closing recap.
    for (var i = 0; i < 5; i++) {
      await tapNext(tester);
    }

    expect(find.text('Y mucho más'), findsOneWidget);
    expect(find.text('Empezar'), findsOneWidget);
    expect(find.text('Siguiente'), findsNothing);
    expect(find.text('Saltar'), findsNothing);

    await tester.tap(find.text('Empezar'));
    await tester.pump();

    expect(finished, isTrue);
  });

  testWidgets('more hero keeps animating without index overflow', (
    tester,
  ) async {
    FlutterErrorDetails? overflow;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is RangeError ||
          details.toString().contains('overflowed')) {
        overflow = details;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(wrap(() {}));
    await tester.pump(const Duration(milliseconds: 1000));

    for (var i = 0; i < 5; i++) {
      await tapNext(tester);
    }

    // Let the breathe loop tick well past the old index++ leak threshold.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Tu capítulo lector'), findsOneWidget);
    expect(find.text('Recordatorios'), findsOneWidget);
    expect(overflow, isNull);
    expect(tester.takeException(), isNull);
  });
}
