import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/core/widgets/timezone_picker_sheet.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'timezone sheet lists IANA zones, searches, and returns a pick ($platform)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        String? picked;
        final light = buildLightTheme();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: light.colorScheme,
              platform: platform,
              cupertinoOverrideTheme: platform == TargetPlatform.iOS
                  ? light.cupertinoOverrideTheme
                  : null,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    picked = await showRdModalSheet<String>(
                      context: context,
                      builder: (_) => const TimezonePickerSheet(
                        selected: 'Europe/Madrid',
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull);
        expect(find.byType(TimezonePickerSheet), findsOneWidget);
        expect(find.byType(RdSearchField), findsOneWidget);
        expect(find.text('Elegir zona horaria'), findsOneWidget);
        expect(find.text('Buscar zona horaria'), findsOneWidget);
        expect(find.byType(ListTile), findsWidgets);

        final searchInput = find.descendant(
          of: find.byType(RdSearchField),
          matching: find.byType(EditableText),
        );
        await tester.enterText(searchInput, 'zzzz-not-a-zone');
        await tester.pump();
        expect(find.text('Sin resultados.'), findsOneWidget);

        await tester.enterText(searchInput, 'Tokyo');
        await tester.pump();
        expect(find.widgetWithText(ListTile, 'Asia/Tokyo'), findsOneWidget);
        await tester.tap(find.widgetWithText(ListTile, 'Asia/Tokyo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(picked, 'Asia/Tokyo');
        expect(find.byType(TimezonePickerSheet), findsNothing);
      },
    );
  }
}
