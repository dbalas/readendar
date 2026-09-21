import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/quotes/share/quote_card_styles.dart';
import 'package:readendar/features/quotes/share/quote_share_card.dart';
import 'package:readendar/features/quotes/share/quote_share_render.dart';

import 'quotes_test_utils.dart';

Future<AppL10n> _l10n() => AppL10n.delegate.load(const Locale('es'));

void main() {
  group('formatQuoteShareText', () {
    testWidgets('full form: «text» — Author, Title, p. X', (tester) async {
      final l = await _l10n();
      final out = formatQuoteShareText(
        l,
        testQuote(page: 12),
        testBook(),
      );
      expect(
        out,
        '«El mundo era tan reciente» — Gabriel García Márquez, '
        'Cien años de soledad, p. 12',
      );
    });

    testWidgets('page clause omitted when unanchored', (tester) async {
      final l = await _l10n();
      final out = formatQuoteShareText(l, testQuote(), testBook());
      expect(out.contains('p.'), isFalse);
      expect(out, endsWith('Cien años de soledad'));
    });

    testWidgets('note excluded by default, appended when included', (
      tester,
    ) async {
      final l = await _l10n();
      final q = testQuote(page: 12, note: 'Mi reflexión');
      final withoutNote = formatQuoteShareText(l, q, testBook());
      expect(withoutNote.contains('Mi reflexión'), isFalse);
      final withNote = formatQuoteShareText(
        l,
        q,
        testBook(),
        includeNote: true,
      );
      expect(withNote, endsWith('\n\nMi reflexión'));
    });

    testWidgets('includeNote is a no-op when the quote has no note', (
      tester,
    ) async {
      final l = await _l10n();
      final q = testQuote(page: 12);
      expect(
        formatQuoteShareText(l, q, testBook(), includeNote: true),
        formatQuoteShareText(l, q, testBook()),
      );
    });

    testWidgets('degrades to the bare quote without a book', (tester) async {
      final l = await _l10n();
      expect(
        formatQuoteShareText(l, testQuote(), null),
        '«El mundo era tan reciente»',
      );
    });
  });

  group('QuoteShareCard', () {
    test('exposes the curated share-card styles', () {
      expect(QuoteCardStyle.values, const [
        QuoteCardStyle.lightElegant,
        QuoteCardStyle.minimal,
        QuoteCardStyle.dark,
        QuoteCardStyle.coverGradient,
        QuoteCardStyle.gradientSunset,
        QuoteCardStyle.gradientForest,
        QuoteCardStyle.gradientOcean,
        QuoteCardStyle.gradientDusk,
        QuoteCardStyle.parchment,
        QuoteCardStyle.mist,
        QuoteCardStyle.pine,
        QuoteCardStyle.honey,
        QuoteCardStyle.noirGold,
      ]);
    });

    test('share palettes stay visually distinct by background family', () {
      final solidStyles = QuoteCardStyle.values.where(
        (s) =>
            paletteFor(s).gradient == null && s != QuoteCardStyle.coverGradient,
      );
      final solidBgs = solidStyles.map((s) => paletteFor(s).background).toList();
      expect(solidBgs.toSet().length, solidBgs.length);

      expect(
        (paletteFor(QuoteCardStyle.gradientOcean).gradient as LinearGradient)
            .colors
            .last,
        isNot(
          (paletteFor(QuoteCardStyle.gradientDusk).gradient as LinearGradient)
              .colors
              .last,
        ),
      );
      expect(
        paletteFor(QuoteCardStyle.noirGold).rule,
        isNot(paletteFor(QuoteCardStyle.dark).rule),
      );
    });

    for (final style in QuoteCardStyle.values) {
      for (final (themeName, theme) in [
        ('light', buildLightTheme()),
        ('dark', buildDarkTheme()),
      ]) {
        testWidgets('renders $style under the $themeName theme', (
          tester,
        ) async {
          await mockNetworkImagesFor(() async {
            final book = testBook(coverUrl: 'https://covers/x.jpg');
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                locale: const Locale('es'),
                localizationsDelegates: AppL10n.localizationsDelegates,
                supportedLocales: AppL10n.supportedLocales,
                home: Scaffold(
                  body: Center(
                    child: FittedBox(
                      child: QuoteShareCard(
                        quote: testQuote(page: 12, favorite: true),
                        book: book,
                        style: style,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('El mundo era tan reciente'), findsOneWidget);
            expect(
              find.textContaining('Gabriel García Márquez'),
              findsOneWidget,
            );
            // Page/chapter now use icons instead of "p." and "cap." abbreviations.
            expect(find.textContaining('12'), findsOneWidget);
            // The wordmark is now a two-tone Text.rich ("Read" + "endar").
            expect(
              find.text('Readendar', findRichText: true),
              findsOneWidget,
            );
            // Fixed sticker art: the card is identical in both themes.
            final size = tester.getSize(find.byType(QuoteShareCard));
            expect(size, kQuoteShareCardSize);
          });
        });
      }
    }
  });
}
