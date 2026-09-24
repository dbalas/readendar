import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/widgets/spoiler_text.dart';

import '../../helpers/linux_goldens.dart';

ThemeData _theme(Brightness brightness) => ThemeData(
  brightness: brightness,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff777cca),
    brightness: brightness,
  ),
);

void main() {
  testWidgets('conceals only text paint and exposes one reveal action', (
    tester,
  ) async {
    var reveals = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.light),
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.format_quote, key: Key('visibleQuoteIcon')),
              RdSpoilerText(
                text: 'A wrapped spoiler that stays inside its own lines',
                semanticsLabel: 'Reveal annotation',
                particlesKey: const Key('lineParticles'),
                onReveal: () => reveals++,
              ),
              const Text('Visible book title'),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('visibleQuoteIcon')), findsOneWidget);
    expect(find.text('Visible book title'), findsOneWidget);
    expect(find.byKey(const Key('lineParticles')), findsOneWidget);
    expect(find.text('Reveal annotation'), findsNothing);
    expect(find.bySemanticsLabel('Reveal annotation'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'A wrapped spoiler that stays inside its own lines',
      ),
      findsNothing,
    );

    await tester.tap(find.bySemanticsLabel('Reveal annotation'));
    expect(reveals, 1);
  });

  testWidgets('supports dark theme, text scaling, wrapping, and ellipsis', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _theme(Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: SizedBox(
              width: 140,
              child: RdSpoilerText(
                text: 'A long spoiler wraps over multiple concealed lines',
                semanticsLabel: 'Reveal annotation',
                maxLines: 2,
                onReveal: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Reveal annotation'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'inline particle veil matches ${brightness.name} golden',
      skip: !runLinuxGoldens,
      (tester) async {
      tester.view.physicalSize = const Size(420, 280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: _theme(brightness),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: RepaintBoundary(
                  key: const Key('spoilerPreview'),
                  child: SizedBox(
                    width: 340,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: RdSpoilerText(
                            text:
                                '“The final page changes everything we knew about the narrator.”',
                            semanticsLabel: 'Reveal annotation',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  height: 1.35,
                                ),
                            onReveal: () {},
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.sticky_note_2_outlined,
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RdSpoilerText(
                                text:
                                    'The note is concealed by its own line only.',
                                semanticsLabel: 'Reveal annotation',
                                onReveal: () {},
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Visible book title',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byKey(const Key('spoilerPreview')),
        matchesGoldenFile('goldens/spoiler_text_${brightness.name}.png'),
      );
    });
  }
}
