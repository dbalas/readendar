import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_root_nav_bar.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const {});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('root destinations fade inside the main shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingEventsProvider.overrideWith(
            (ref) async => const <ReadingEvent>[],
          ),
          booksProvider.overrideWith((ref) async => const <Book>[]),
          isOnlineProvider.overrideWith((ref) => Stream.value(true)),
          shellCalendarNovedadesDotProvider.overrideWithValue(false),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const MainShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RdRootNavBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RdRootNavBar),
        matching: find.text('BETA'),
      ),
      findsNothing,
    );

    Finder tabPage(int index, {bool skipOffstage = true}) => find.descendant(
      of: find.byType(ReadendarTabSwitcher),
      matching: find.byKey(ValueKey<int>(index), skipOffstage: skipOffstage),
      skipOffstage: skipOffstage,
    );

    expect(find.byType(ReadendarTabSwitcher), findsOneWidget);
    expect(tabPage(0), findsOneWidget);

    tester
        .widget<RdRootNavBar>(find.byType(RdRootNavBar))
        .onDestinationSelected(1);
    await tester.pump();

    expect(tabPage(0), findsNothing);
    expect(tabPage(1), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('retained-tab-1')),
        matching: find.byType(FadeTransition),
      ),
      findsOneWidget,
    );

    await tester.pumpAndSettle();

    expect(tabPage(0, skipOffstage: false), findsOneWidget);
    expect(tabPage(1), findsOneWidget);
  });

  testWidgets('You tab is the fourth root destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          upcomingEventsProvider.overrideWith(
            (ref) async => const <ReadingEvent>[],
          ),
          booksProvider.overrideWith((ref) async => const <Book>[]),
          isOnlineProvider.overrideWith((ref) => Stream.value(true)),
          shellCalendarNovedadesDotProvider.overrideWithValue(false),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const MainShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<RdRootNavBar>(find.byType(RdRootNavBar));
    expect(bar.destinations.length, 4);
    expect(bar.destinations.last.label, 'Perfil');
  });

  testWidgets(
    'Calendar nav dot sits on the icon via Stack inset',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            upcomingEventsProvider.overrideWith(
              (ref) async => const <ReadingEvent>[],
            ),
            booksProvider.overrideWith((ref) async => const <Book>[]),
            isOnlineProvider.overrideWith((ref) => Stream.value(true)),
            shellCalendarNovedadesDotProvider.overrideWithValue(true),
              sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const MainShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final calendarDot = find.byKey(const Key('calendarNavNovedadesDot'));
      expect(
        find.descendant(of: find.byType(RdRootNavBar), matching: calendarDot),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: calendarDot, matching: find.byType(Stack)),
        findsWidgets,
      );
      expect(
        find.ancestor(of: calendarDot, matching: find.byType(Badge)),
        findsNothing,
      );
      final positioned = tester.widget<Positioned>(calendarDot);
      expect(positioned.right, 2);
      expect(positioned.bottom, 2);
    },
  );

  testWidgets(
    'system back pops nested routes before walking root-tab history',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            upcomingEventsProvider.overrideWith(
              (ref) async => const <ReadingEvent>[],
            ),
            booksProvider.overrideWith((ref) async => const <Book>[]),
            isOnlineProvider.overrideWith((ref) => Stream.value(true)),
            shellCalendarNovedadesDotProvider.overrideWithValue(false),
              sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const MainShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<RdRootNavBar>(find.byType(RdRootNavBar)).selectedIndex,
        0,
      );

      tester
          .widget<RdRootNavBar>(find.byType(RdRootNavBar))
          .onDestinationSelected(1);
      await tester.pumpAndSettle();
      tester
          .widget<RdRootNavBar>(find.byType(RdRootNavBar))
          .onDestinationSelected(3);
      // Profile tab hero may keep ambient motion; one transition is enough
      // to assert the back-stack behavior below.
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.widget<RdRootNavBar>(find.byType(RdRootNavBar)).selectedIndex,
        3,
      );

      final nestedRoute = tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Nested screen')),
            ),
          );
      await tester.pumpAndSettle();

      expect(find.text('Nested screen'), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await nestedRoute;

      expect(find.text('Nested screen'), findsNothing);
      expect(
        tester.widget<RdRootNavBar>(find.byType(RdRootNavBar)).selectedIndex,
        3,
      );

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(
        tester.widget<RdRootNavBar>(find.byType(RdRootNavBar)).selectedIndex,
        1,
      );

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(
        tester.widget<RdRootNavBar>(find.byType(RdRootNavBar)).selectedIndex,
        0,
      );

      // Explicitly selecting Home also resets the root-tab history. Back must
      // exit from Home rather than resurrecting an older non-home tab.
      tester
          .widget<RdRootNavBar>(find.byType(RdRootNavBar))
          .onDestinationSelected(1);
      await tester.pumpAndSettle();
      tester
          .widget<RdRootNavBar>(find.byType(RdRootNavBar))
          .onDestinationSelected(3);
      await tester.pump(const Duration(milliseconds: 300));
      tester
          .widget<RdRootNavBar>(find.byType(RdRootNavBar))
          .onDestinationSelected(0);
      await tester.pumpAndSettle();

      // Home is the root destination. With no pushed route left, back is free
      // to bubble to Android so the app can close.
      expect(await tester.binding.handlePopRoute(), isFalse);
    },
  );

  testWidgets('indexed switcher retains a visited tab state', (tester) async {
    var firstTabInits = 0;
    var secondTabInits = 0;

    Widget shell(int index, Set<int> visited) => MaterialApp(
      home: ReadendarTabSwitcher.indexed(
        index: index,
        visited: visited,
        children: [
          _LifecycleProbe(onInit: () => firstTabInits++),
          _LifecycleProbe(onInit: () => secondTabInits++),
        ],
      ),
    );

    await tester.pumpWidget(shell(0, {0}));
    await tester.pumpAndSettle();
    await tester.pumpWidget(shell(1, {0, 1}));
    await tester.pumpAndSettle();
    await tester.pumpWidget(shell(0, {0, 1}));
    await tester.pumpAndSettle();

    expect(firstTabInits, 1);
    expect(secondTabInits, 1);
  });
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
