import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/book_row.dart';
import 'package:readendar/core/widgets/card.dart';

void main() {
  final book = Book(
    id: 'b1',
    ownerType: OwnerType.user,
    ownerId: 'u1',
    title: 'Shared Novel',
    authors: const ['Ada'],
    status: BookStatus.read,
  );

  Widget wrap(Widget child) => MaterialApp(
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    locale: const Locale('es'),
    home: Scaffold(body: child),
  );

  testWidgets('footer renders inside the same RdCard as the book meta', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        BookRow(
          book: book,
          footer: const Text('Loved it.', key: Key('rowFooter')),
        ),
      ),
    );

    expect(find.byType(RdCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RdCard),
        matching: find.byKey(const Key('rowFooter')),
      ),
      findsOneWidget,
    );
    expect(find.text('Shared Novel'), findsWidgets);
    expect(find.text('Loved it.'), findsOneWidget);
  });

  testWidgets('omits footer when not provided', (tester) async {
    await tester.pumpWidget(wrap(BookRow(book: book)));

    expect(find.byType(RdCard), findsOneWidget);
    expect(find.text('Shared Novel'), findsWidgets);
    expect(find.byKey(const Key('rowFooter')), findsNothing);
  });

  testWidgets('omits ISBN caption by default', (tester) async {
    await tester.pumpWidget(
      wrap(
        BookRow(
          book: Book(
            id: 'b1',
            ownerType: OwnerType.user,
            ownerId: 'u1',
            title: 'Shared Novel',
            authors: const ['Ada'],
            status: BookStatus.read,
            isbn13: '9780441172719',
          ),
        ),
      ),
    );

    expect(find.text('978-0-441-17271-9'), findsNothing);
  });

  testWidgets('shows a small ISBN-13 caption when showIsbn is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        BookRow(
          showIsbn: true,
          book: Book(
            id: 'b1',
            ownerType: OwnerType.user,
            ownerId: 'u1',
            title: 'Shared Novel',
            authors: const ['Ada'],
            status: BookStatus.read,
            isbn13: '9780441172719',
          ),
        ),
      ),
    );

    expect(find.text('978-0-441-17271-9'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('falls back to ISBN-10 when ISBN-13 is empty', (tester) async {
    await tester.pumpWidget(
      wrap(
        BookRow(
          showIsbn: true,
          book: Book(
            id: 'b1',
            ownerType: OwnerType.user,
            ownerId: 'u1',
            title: 'Shared Novel',
            authors: const ['Ada'],
            status: BookStatus.read,
            isbn10: '076531178X',
          ),
        ),
      ),
    );

    expect(find.text('0-7653-1178-X'), findsOneWidget);
  });

  testWidgets('omits the ISBN caption when both identifiers are empty', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(BookRow(book: book)));

    expect(find.text('978-0-441-17271-9'), findsNothing);
  });

  testWidgets('same-title rows stay distinguishable by ISBN when showIsbn', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            BookRow(
              showIsbn: true,
              book: Book(
                id: 'a',
                ownerType: OwnerType.user,
                ownerId: 'u1',
                title: 'Shared Novel',
                authors: const ['Ada'],
                status: BookStatus.read,
                isbn13: '9780441172719',
              ),
            ),
            BookRow(
              showIsbn: true,
              book: Book(
                id: 'b',
                ownerType: OwnerType.user,
                ownerId: 'u1',
                title: 'Shared Novel',
                authors: const ['Ada'],
                status: BookStatus.read,
                isbn13: '9780306406157',
              ),
            ),
          ],
        ),
      ),
    );

    expect(find.text('978-0-441-17271-9'), findsOneWidget);
    expect(find.text('978-0-306-40615-7'), findsOneWidget);
  });

  testWidgets('caption chip replaces ISBN when both are set', (tester) async {
    await tester.pumpWidget(
      wrap(
        BookRow(
          showIsbn: true,
          caption: '5 oct 2026',
          book: Book(
            id: 'b1',
            ownerType: OwnerType.user,
            ownerId: 'u1',
            title: 'Nieve',
            authors: const ['Nieves'],
            status: BookStatus.pending,
            isbn13: '9780441172719',
          ),
        ),
      ),
    );

    expect(find.text('5 oct 2026'), findsOneWidget);
    expect(find.text('978-0-441-17271-9'), findsNothing);
  });
}
