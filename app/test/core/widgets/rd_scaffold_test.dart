import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/icon_fonts.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/rd_scaffold.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('RdScaffold uses adaptive chrome on $platform', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: const RdScaffold(
            title: Text('Chapter'),
            body: SizedBox(),
          ),
        ),
      );

      if (platform == TargetPlatform.iOS) {
        expect(find.byType(CupertinoNavigationBar), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
      } else {
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(CupertinoNavigationBar), findsNothing);
      }
      expect(find.byIcon(rdBackIconData(platform)), findsNothing);
    });

    testWidgets('RdScaffold back uses the shared platform glyph on $platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  rdPageRoute<void>(
                    context,
                    builder: (_) => const RdScaffold(
                      title: Text('History'),
                      body: SizedBox(),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
      expect(find.byType(CupertinoNavigationBarBackButton), findsNothing);
      expect(find.byIcon(rdBackIconData(platform)), findsOneWidget);

      await tester.tap(find.byIcon(rdBackIconData(platform)));
      await tester.pumpAndSettle();
      expect(find.text('History'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('rdPageRoute uses adaptive route on $platform', (tester) async {
      late PageRoute<void> route;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) {
              route = rdPageRoute<void>(
                context,
                builder: (_) => const SizedBox(),
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        route,
        platform == TargetPlatform.iOS
            ? isA<CupertinoPageRoute<void>>()
            : isA<MaterialPageRoute<void>>(),
      );
    });
  }
}
