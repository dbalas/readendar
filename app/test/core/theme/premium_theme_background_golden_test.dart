import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_background.dart';
import 'package:readendar/core/theme/theme_catalog.dart';

import '../../helpers/linux_goldens.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'premium backgrounds have dense distinct ${brightness.name} artwork',
      skip: !runLinuxGoldens,
      (tester) async {
        tester.view.physicalSize = const Size(900, 1180);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final shellTheme = brightness == Brightness.dark
            ? buildDarkTheme()
            : buildLightTheme();
        await tester.pumpWidget(
          MaterialApp(
            theme: shellTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: RepaintBoundary(
                key: const Key('premium-background-gallery'),
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 220,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: ReadendarThemes.premium.length,
                  itemBuilder: (context, index) {
                    final definition = ReadendarThemes.premium[index];
                    final theme = brightness == Brightness.dark
                        ? buildDarkTheme(themeId: definition.id)
                        : buildLightTheme(themeId: definition.id);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Theme(
                        data: theme,
                        child: ReadendarThemeBackground(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              margin: const EdgeInsets.all(12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                definition.id.wire,
                                style: theme.textTheme.labelMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const Key('premium-background-gallery')),
          matchesGoldenFile(
            'goldens/premium_backgrounds_${brightness.name}.png',
          ),
        );
      },
    );
  }
}
