import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_background.dart';
import 'package:readendar/core/theme/theme_catalog.dart';

void main() {
  test('every platform uses the fast fade route transition', () {
    for (final theme in [buildLightTheme(), buildDarkTheme()]) {
      for (final platform in TargetPlatform.values) {
        final builder = theme.pageTransitionsTheme.builders[platform];
        expect(builder, isA<ReadendarPageTransitionsBuilder>());
        expect(builder?.transitionDuration, ReadendarMotion.fast);
        expect(builder?.reverseTransitionDuration, ReadendarMotion.fast);
      }
    }
  });

  testWidgets(
    'route fade paints its theme canvas during push and pop',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(themeId: ReadendarThemeId.celestial),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    key: ValueKey('route-child'),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReadendarThemeBackground), findsNothing);
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(ReadendarMotion.fast ~/ 2);

      final routeBackground = find.byType(ReadendarThemeBackground);
      expect(routeBackground, findsOneWidget);
      expect(
        tester.widget<ReadendarThemeBackground>(routeBackground).animateEffects,
        isFalse,
      );
      expect(
        find.descendant(
          of: routeBackground,
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: routeBackground,
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, greaterThan(0.25));
      expect(fade.opacity.value, lessThan(0.75));
      expect(
        find.descendant(
          of: routeBackground,
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-child')), findsOneWidget);
      expect(find.byType(ReadendarThemeBackground), findsNothing);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pump();
      await tester.pump(ReadendarMotion.fast ~/ 2);
      expect(find.byType(ReadendarThemeBackground), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('route-child')), findsNothing);
      expect(find.byType(ReadendarThemeBackground), findsNothing);
    },
  );

  testWidgets('retained root destinations fade when their index changes', (
    tester,
  ) async {
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              Expanded(
                child: ReadendarTabSwitcher.indexed(
                  index: index,
                  visited: const {0, 1},
                  children: const [Text('first'), Text('second')],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => index = 1),
                child: const Text('switch'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('switch'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(ReadendarMotion.fast ~/ 2);

    final incoming = find.descendant(
      of: find.byKey(const ValueKey<String>('retained-tab-1')),
      matching: find.byType(FadeTransition),
    );
    expect(incoming, findsOneWidget);
    final opacity = tester.widget<FadeTransition>(incoming).opacity.value;
    expect(opacity, greaterThan(0));
    expect(opacity, lessThan(1));

    await tester.pumpAndSettle();
    expect(
      tester.widget<FadeTransition>(incoming).opacity.value,
      equals(1),
    );
  });

  testWidgets('route transition is removed when animations are disabled', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    const child = SizedBox(key: ValueKey('route-child'));
    final transition = const ReadendarPageTransitionsBuilder().buildTransitions(
      MaterialPageRoute<void>(builder: (_) => child),
      context,
      const AlwaysStoppedAnimation(1),
      const AlwaysStoppedAnimation(0),
      child,
    );

    expect(transition, same(child));
  });

  testWidgets(
    'inactive retained tabs exclude focus so searchers cannot keep the keyboard',
    (tester) async {
      final focusA = FocusNode();
      final focusB = FocusNode();
      addTearDown(focusA.dispose);
      addTearDown(focusB.dispose);

      var index = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    Expanded(
                      child: ReadendarTabSwitcher.indexed(
                        index: index,
                        visited: const {0, 1},
                        animate: false,
                        children: [
                          TextField(
                            key: const Key('tab-a-field'),
                            focusNode: focusA,
                          ),
                          TextField(
                            key: const Key('tab-b-field'),
                            focusNode: focusB,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => index = 1),
                      child: const Text('go-tab-b'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('tab-a-field')));
      await tester.pump();
      expect(focusA.hasFocus, isTrue);

      await tester.tap(find.text('go-tab-b'));
      await tester.pump();

      expect(focusA.hasFocus, isFalse);
      expect(focusB.hasFocus, isFalse);

      final excluded = tester
          .widgetList<ExcludeFocus>(find.byType(ExcludeFocus))
          .toList();
      expect(excluded, hasLength(2));
      expect(excluded.where((w) => w.excluding), hasLength(1));
      expect(excluded.where((w) => !w.excluding), hasLength(1));
    },
  );
}
