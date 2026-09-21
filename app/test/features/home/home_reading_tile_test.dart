import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/home/home_screen.dart';

AppUser _testUser() => AppUser(
  id: 'user-1',
  email: 'reader@example.com',
  displayName: 'Reader',
  preferredLocale: 'es',
  timezone: 'Europe/Madrid',
  onboardingCompletedAt: DateTime(2026, 7),
);

class _Session extends SessionNotifier {
  _Session(super.ref, AppUser user) {
    state = SessionState(user: user);
  }
}

Book _book({required String title, String author = 'Juan Rulfo'}) => Book(
  id: 'book-1',
  ownerType: 'user',
  ownerId: 'user-1',
  title: title,
  authors: [author],
  status: BookStatus.reading,
);

Text _caption(WidgetTester tester, String title) => tester.widget<Text>(
  find.byWidgetPredicate(
    (w) =>
        w is Text &&
        w.data == title &&
        w.style?.fontWeight == FontWeight.w700 &&
        w.style?.fontSize == 12,
  ),
);

RenderParagraph _captionParagraph(WidgetTester tester, String title) =>
    tester.renderObject<RenderParagraph>(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data == title &&
            w.style?.fontWeight == FontWeight.w700 &&
            w.style?.fontSize == 12,
      ),
    );

Future<void> _pumpHome(
  WidgetTester tester, {
  required Book book,
  double textScale = 1,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) => _Session(ref, _testUser())),
        booksProvider.overrideWith((ref) async => [book]),
        upcomingEventsProvider.overrideWith(
          (ref) async => const <ReadingEvent>[],
        ),
        progressProvider(book.id).overrideWith(
          (ref) async => Progress(bookEntryId: book.id),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('short reading titles wrap fully under the cover', (tester) async {
    const title = 'Pedro Paramo';
    await _pumpHome(tester, book: _book(title: title));

    final caption = _caption(tester, title);
    expect(caption.maxLines, 3);
    expect(caption.overflow, TextOverflow.ellipsis);
    expect(caption.softWrap, isTrue);
    expect(_captionParagraph(tester, title).didExceedMaxLines, isFalse);
  });

  testWidgets(
    'long reading titles wrap then ellipsize instead of clipping',
    (tester) async {
      const title =
          'A Very Long Book Title That Should Wrap Across Several Lines Then Ellipsize Gracefully';
      await _pumpHome(tester, book: _book(title: title));

      final caption = _caption(tester, title);
      expect(caption.maxLines, 3);
      expect(caption.overflow, TextOverflow.ellipsis);
      expect(_captionParagraph(tester, title).didExceedMaxLines, isTrue);
    },
  );

  testWidgets(
    'large text scale still truncates the reading title without overflow',
    (tester) async {
      const title =
          'A Very Long Book Title That Should Wrap Across Several Lines Then Ellipsize Gracefully';
      await _pumpHome(tester, book: _book(title: title), textScale: 1.6);

      expect(_caption(tester, title).overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    },
  );
}
