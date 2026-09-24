import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/widgets/theme_preview_card.dart';

import '../../helpers/linux_goldens.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'all theme previews match ${brightness.name} golden',
      skip: !runLinuxGoldens,
      (tester) async {
      tester.view.physicalSize = const Size(820, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellTheme = brightness == Brightness.dark
          ? buildDarkTheme()
          : buildLightTheme();
      await tester.pumpWidget(
        MaterialApp(
          theme: shellTheme,
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('theme-preview-grid'),
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 132,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: ReadendarThemes.standard.length,
                itemBuilder: (context, index) {
                  final definition = ReadendarThemes.standard[index];
                  return ThemePreviewCard(
                    definition: definition,
                    label: definition.id.name,
                    brightness: brightness,
                    selected: index == 0,
                    enabled: true,
                    onPressed: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('theme-preview-grid')),
        matchesGoldenFile('goldens/theme_previews_${brightness.name}.png'),
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'Ethereal premium preview matches ${brightness.name} golden',
      skip: !runLinuxGoldens,
      (tester) async {
      tester.view.physicalSize = const Size(420, 176);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellTheme = brightness == Brightness.dark
          ? buildDarkTheme()
          : buildLightTheme();
      await tester.pumpWidget(
        MaterialApp(
          theme: shellTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: const Key('premium-theme-preview'),
                child: ThemePreviewCard(
                  definition: ReadendarThemes.ethereal,
                  label: 'Ethereal',
                  brightness: brightness,
                  selected: true,
                  enabled: true,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 3960));

      expect(
        find.byKey(const Key('premiumIdentityPreview-ethereal')),
        findsOneWidget,
      );

      await expectLater(
        find.byKey(const Key('premium-theme-preview')),
        matchesGoldenFile(
          'goldens/premium_theme_preview_${brightness.name}.png',
        ),
      );
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      'all premium previews match ${brightness.name} golden',
      skip: !runLinuxGoldens,
      (tester) async {
      tester.view.physicalSize = const Size(820, 748);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final shellTheme = brightness == Brightness.dark
          ? buildDarkTheme()
          : buildLightTheme();
      await tester.pumpWidget(
        MaterialApp(
          theme: shellTheme,
          home: Scaffold(
            body: RepaintBoundary(
              key: const Key('premium-theme-preview-grid'),
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 132,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: ReadendarThemes.premium.length,
                itemBuilder: (context, index) {
                  final definition = ReadendarThemes.premium[index];
                  return ThemePreviewCard(
                    definition: definition,
                    label: definition.id.name,
                    brightness: brightness,
                    selected: index == 0,
                    enabled: true,
                    onPressed: () {},
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 3960));

      await expectLater(
        find.byKey(const Key('premium-theme-preview-grid')),
        matchesGoldenFile(
          'goldens/premium_theme_previews_${brightness.name}.png',
        ),
      );
    });
  }

  for (final definition in ReadendarThemes.premium) {
    testWidgets(
      '${definition.id.name} preview exposes and advances its effect',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(),
            home: Scaffold(
              body: ThemePreviewCard(
                definition: definition,
                label: definition.id.name,
                brightness: Brightness.light,
                selected: false,
                enabled: true,
                onPressed: () {},
              ),
            ),
          ),
        );

        final card = find.byType(ThemePreviewCard);
        expect(
          find.descendant(
            of: card,
            matching: find.byKey(
              Key('premiumIdentityPreview-${definition.id.wire}'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.byKey(const Key('premium-theme-animation')),
          ),
          findsOneWidget,
        );

        final painterFinder = find.descendant(
          of: card,
          matching: find.byKey(
            Key(
              'premium-theme-painter-${definition.lightBackground.effect.name}',
            ),
          ),
        );
        final before = tester.widget<CustomPaint>(painterFinder).painter!;
        await tester.pump(const Duration(seconds: 1));
        final after = tester.widget<CustomPaint>(painterFinder).painter!;
        expect(after.shouldRepaint(before), isTrue);
      },
    );
  }

  testWidgets('Material preview clips its background and ink to the frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: ThemePreviewCard(
            definition: ReadendarThemes.original,
            label: 'Original',
            brightness: Brightness.light,
            selected: true,
            enabled: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(ThemePreviewCard),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, Colors.transparent);
    expect(material.clipBehavior, Clip.antiAlias);
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(18));

    final frame = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(ThemePreviewCard),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final background = frame.decoration! as BoxDecoration;
    expect(background.color, ReadendarThemes.original.light.surface1);
    expect(background.borderRadius, BorderRadius.circular(18));
    final foreground = frame.foregroundDecoration! as BoxDecoration;
    expect(foreground.borderRadius, BorderRadius.circular(18));
    expect((foreground.border! as Border).top.width, 2);
  });

  testWidgets('title appears once and selected state overlays the preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ThemePreviewCard(
            definition: ReadendarThemes.original,
            label: 'Original',
            brightness: Brightness.light,
            selected: true,
            enabled: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Original'), findsOneWidget);
    final cardRect = tester.getRect(find.byType(ThemePreviewCard));
    expect(cardRect.height, 132);

    final check = find.byIcon(Icons.check_rounded);
    expect(check, findsOneWidget);
    expect(
      find.ancestor(of: check, matching: find.byType(Stack)),
      findsOneWidget,
    );
    final checkCenter = tester.getCenter(check);
    expect(checkCenter.dx, greaterThan(cardRect.right - 42));
    expect(checkCenter.dy, lessThan(cardRect.top + 42));
  });

  testWidgets('long translated titles scale down instead of truncating', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ThemePreviewCard(
            definition: ReadendarThemes.stormbound,
            label: 'Very long translated theme name',
            brightness: Brightness.light,
            selected: false,
            enabled: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    final title = find.text('Very long translated theme name');
    expect(title, findsOneWidget);
    expect(
      find.ancestor(of: title, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(tester.widget<Text>(title).overflow, isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);
  });
}
