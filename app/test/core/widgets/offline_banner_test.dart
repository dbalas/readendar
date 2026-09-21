import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/offline_banner.dart';

Widget _app({required bool online}) => MaterialApp(
  theme: buildLightTheme(),
  locale: const Locale('es'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: Scaffold(
    body: Column(children: [OfflineBanner(online: online)]),
  ),
);

void main() {
  testWidgets('shows the banner while offline', (tester) async {
    await tester.pumpWidget(_app(online: false));
    await tester.pump();
    expect(
      find.text('Sin conexión: se muestran datos guardados'),
      findsOneWidget,
    );
  });

  testWidgets('renders nothing while online', (tester) async {
    await tester.pumpWidget(_app(online: true));
    await tester.pump();
    expect(find.byType(Text), findsNothing);
  });
}
