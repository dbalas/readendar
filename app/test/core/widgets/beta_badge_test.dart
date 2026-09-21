import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/beta_badge.dart';

void main() {
  Widget wrap(ThemeData theme) => MaterialApp(
    locale: const Locale('es'),
    theme: theme,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: const Scaffold(
      body: Center(child: BetaBadge()),
    ),
  );

  testWidgets('BetaBadge shows localized BETA in light and dark', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildLightTheme()));
    expect(find.text('BETA'), findsOneWidget);
    expect(find.byType(BetaBadge), findsOneWidget);

    await tester.pumpWidget(wrap(buildDarkTheme()));
    expect(find.text('BETA'), findsOneWidget);
  });

  testWidgets('BetaTitledText pairs title with badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          appBar: AppBar(title: const BetaTitledText('Lectura')),
        ),
      ),
    );
    expect(find.text('Lectura'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(BetaBadge),
      ),
      findsOneWidget,
    );
  });
}
