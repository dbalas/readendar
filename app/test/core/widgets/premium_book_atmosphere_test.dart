import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/widgets/premium_book_atmosphere.dart';

void main() {
  testWidgets('Ethereal book atmosphere grows a progress constellation', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(themeId: ReadendarThemeId.ethereal),
        home: Scaffold(
          body: PremiumBookAtmosphere(
            themeId: ReadendarThemeId.ethereal,
            coverUrl: '',
            coverColorsEnabled: false,
            scrollController: scroll,
            progressFraction: 0.65,
            child: const SizedBox(width: 280, height: 180),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('etherealBookConstellation')), findsOneWidget);
    expect(find.byKey(const Key('etherealBookHalo')), findsOneWidget);
  });

  for (final definition in ReadendarThemes.premium.where(
    (theme) => theme.id != ReadendarThemeId.ethereal,
  )) {
    testWidgets('${definition.id.name} owns distinct book artwork', (
      tester,
    ) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(themeId: definition.id),
          home: Scaffold(
            body: PremiumBookAtmosphere(
              themeId: definition.id,
              coverUrl: '',
              coverColorsEnabled: false,
              scrollController: scroll,
              progressFraction: 0.65,
              child: const SizedBox(width: 280, height: 180),
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          Key('premiumBookArtwork-${definition.identity.effect.name}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('premiumBookHalo-${definition.identity.effect.name}')),
        findsOneWidget,
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'Ethereal book atmosphere uses constellation paths in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(420, 260);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: brightness == Brightness.dark
                ? buildDarkTheme(themeId: ReadendarThemeId.ethereal)
                : buildLightTheme(themeId: ReadendarThemeId.ethereal),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: const Key('book-atmosphere-golden'),
                  child: PremiumBookAtmosphere(
                    themeId: ReadendarThemeId.ethereal,
                    coverUrl: '',
                    coverColorsEnabled: false,
                    scrollController: scroll,
                    progressFraction: 1,
                    child: SizedBox(
                      width: 340,
                      height: 190,
                      child: Row(
                        children: [
                          Container(
                            width: 82,
                            height: 128,
                            decoration: BoxDecoration(
                              color: const Color(0xCC17142B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 142,
                                  height: 15,
                                  color: const Color(0xCCF8F5FF),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: 104,
                                  height: 8,
                                  color: const Color(0x99D2C9EA),
                                ),
                                const SizedBox(height: 26),
                                Container(
                                  width: 174,
                                  height: 7,
                                  color: const Color(0x88B6A2FF),
                                ),
                              ],
                            ),
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
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const Key('book-atmosphere-golden')),
          matchesGoldenFile(
            'goldens/premium_book_atmosphere_${brightness.name}.png',
          ),
        );
      },
    );
  }

  testWidgets(
    'cover palette extraction stays local and preserves dominant hue',
    (
      tester,
    ) async {
      final color = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 8, 8),
          Paint()..color = const Color(0xFFCA3158),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(8, 8);
        picture.dispose();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        expect(bytes, isNotNull);

        final provider = MemoryImage(bytes!.buffer.asUint8List());
        final first = await CoverPaletteExtractor.dominantColor(
          provider,
          ImageConfiguration.empty,
        );
        final cached = await CoverPaletteExtractor.dominantColor(
          provider,
          ImageConfiguration.empty,
        );
        expect(cached, first);
        return first;
      });

      expect(color, isNotNull);
      expect(color!.r, closeTo(0xCA / 255, 0.02));
      expect(color.g, closeTo(0x31 / 255, 0.02));
      expect(color.b, closeTo(0x58 / 255, 0.02));
    },
  );
}
