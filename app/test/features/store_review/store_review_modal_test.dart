import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/store_review/store_review_modal.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('shows App Store CTA on iOS and returns review on tap', (
    tester,
  ) async {
    StoreReviewModalResult? result;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showStoreReviewModal(
                context,
                platform: TargetPlatform.iOS,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump(); // open dialog
    await tester.pump(const Duration(milliseconds: 400)); // transition

    expect(find.text('¿Te está gustando Readendar?'), findsOneWidget);
    expect(find.text('Valorar en App Store'), findsOneWidget);

    await tester.tap(find.text('Valorar en App Store'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, StoreReviewModalResult.review);
  });

  testWidgets('shows Play Store CTA on Android and dismisses on Not now', (
    tester,
  ) async {
    StoreReviewModalResult? result;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showStoreReviewModal(
                context,
                platform: TargetPlatform.android,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Valorar en Google Play'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, StoreReviewModalResult.dismissed);
  });
}
