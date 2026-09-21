import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/library/book_field_cards.dart';

void main() {
  test('bookNotesPreview collapses whitespace for card subtitles', () {
    expect(
      bookNotesPreview('**Hello**\n\nworld\n- item'),
      'Hello world item',
    );
  });

  test('bookNotesBody keeps paragraph breaks for full review sheets', () {
    expect(
      bookNotesBody('**Hello**\n\nworld\n\nmore'),
      'Hello\n\nworld\n\nmore',
    );
  });

  test('BookRatingDisplay.reviewCaption collapses whitespace', () {
    expect(
      BookRatingDisplay.reviewCaption('line one\nline  two'),
      'line one line two',
    );
  });

  testWidgets('BookRatingDisplay shows stars, score, and review caption', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: BookRatingDisplay(
            rating: 4.5,
            review: 'Dusty\nvoices',
            reviewKey: Key('preview'),
          ),
        ),
      ),
    );

    expect(find.byType(BookStaticStars), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(find.text('Dusty voices'), findsOneWidget);
    expect(find.byIcon(LucideIcons.pencil), findsNothing);
  });

  testWidgets('unrated BookRatingDisplay shows edit pencil when requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: BookRatingDisplay(rating: null, showEditHint: true),
        ),
      ),
    );

    expect(find.byType(BookStaticStars), findsOneWidget);
    expect(find.byIcon(LucideIcons.pencil), findsOneWidget);
  });
}
