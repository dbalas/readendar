import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_large_title.dart';

ThemeData _iosTheme() =>
    buildLightTheme().copyWith(platform: TargetPlatform.iOS);

ThemeData _androidTheme() =>
    buildLightTheme().copyWith(platform: TargetPlatform.android);

Future<void> _withIosPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('RdLargeTitleScaffold uses Cupertino large title on iOS', (
    tester,
  ) async {
    await _withIosPlatform(() async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          theme: _iosTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const RdLargeTitleScaffold(
            title: Text('Library'),
            bodySlivers: [
              SliverToBoxAdapter(child: Text('body')),
            ],
          ),
        ),
      );
      expect(find.byType(CupertinoSliverNavigationBar), findsOneWidget);
      expect(find.text('Library'), findsWidgets);
      expect(find.byType(SliverAppBar), findsNothing);
      // Root tabs stay mounted side-by-side — Hero route transitions collide
      // across siblings when left enabled.
      final bar = tester.widget<CupertinoSliverNavigationBar>(
        find.byType(CupertinoSliverNavigationBar),
      );
      expect(bar.transitionBetweenRoutes, isFalse);
    });
  });

  testWidgets('RdLargeTitleScaffold uses SliverAppBar.large on Android', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: _androidTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const RdLargeTitleScaffold(
          title: Text('Library'),
          bodySlivers: [
            SliverToBoxAdapter(child: Text('body')),
          ],
        ),
      ),
    );
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.byType(CupertinoSliverNavigationBar), findsNothing);
  });
}
