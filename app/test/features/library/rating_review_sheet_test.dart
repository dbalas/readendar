import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/features/library/rating_review_sheet.dart';
import 'package:readendar/features/library/rating_sheet.dart';

void main() {
  testWidgets('default rating 0 is valid and review is editable immediately', (
    tester,
  ) async {
    RatingReviewValue? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showRatingReviewSheet(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text(' / 5'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).enabled ?? true,
      isTrue,
    );
    expect(
      tester
          .widget<RdButton>(find.byKey(const Key('rating-review-save')))
          .onPressed,
      isNotNull,
    );

    await tester.enterText(find.byType(TextField), 'Zero stars, still a review');
    await tester.tap(find.byKey(const Key('rating-review-save')));
    await tester.pumpAndSettle();

    expect(result?.save, isTrue);
    expect(result?.rating, 0);
    expect(result?.review, 'Zero stars, still a review');
  });

  testWidgets('picking a rating returns one atomic value with the review', (
    tester,
  ) async {
    RatingReviewValue? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showRatingReviewSheet(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final topLeft = tester.getTopLeft(find.byType(HalfStarPicker));
    await tester.tapAt(topLeft + const Offset(4 * 42 + 10, 20));
    await tester.pumpAndSettle();
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text(' / 5'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '**Excellent**');
    await tester.tap(find.byKey(const Key('rating-review-save')));
    await tester.pumpAndSettle();

    expect(result?.save, isTrue);
    expect(result?.rating, 4.5);
    expect(result?.review, '**Excellent**');
  });

  testWidgets('editing an existing rating shows the numeric readout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                await showRatingReviewSheet(
                  context,
                  currentRating: 4,
                  currentReview: 'Great',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text(' / 5'), findsOneWidget);
    expect(find.text('Sin valorar'), findsNothing);
  });
}
