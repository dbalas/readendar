import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/book_row.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/quotes/quote_book_picker.dart';

import 'quotes_test_utils.dart';

Widget _host(List<Book> books) {
  return ProviderScope(
    overrides: [booksProvider.overrideWith((ref) async => books)],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => pickQuoteBook(context),
            child: const Text('Pick book'),
          ),
        ),
      ),
    ),
  );
}

Finder _sectionHeader(String text) => find.byWidgetPredicate(
  (widget) => widget is SectionHeader && widget.text == text,
);

void main() {
  testWidgets(
    'groups books by Library status with Library rows and semantic colors',
    (tester) async {
      final books = [
        testBook(id: 'reading', title: 'Reading book'),
        testBook(
          id: 'pending',
          title: 'Pending book',
          status: BookStatus.pending,
        ),
        testBook(id: 'wanted', title: 'Wanted book', status: BookStatus.wanted),
        testBook(id: 'read', title: 'Read book', status: BookStatus.read),
        testBook(
          id: 'abandoned',
          title: 'Abandoned book',
          status: BookStatus.abandoned,
        ),
      ];
      await tester.pumpWidget(_host(books));
      await tester.tap(find.text('Pick book'));
      await tester.pumpAndSettle();

      expect(find.byType(BookRow, skipOffstage: false), findsAtLeastNWidgets(3));
      expect(_sectionHeader('Leyendo'), findsOneWidget);
      expect(_sectionHeader('Pendiente'), findsOneWidget);
      expect(_sectionHeader('Deseado'), findsOneWidget);

      final pendingHeader = tester.widget<SectionHeader>(
        _sectionHeader('Pendiente'),
      );
      expect(
        pendingHeader.padding,
        const EdgeInsets.fromLTRB(4, 16, 4, 8),
      );
      expect(pendingHeader.count, 1);
      final pendingContext = tester.element(_sectionHeader('Pendiente'));
      expect(
        pendingHeader.color,
        bookStatusColor(BookStatus.pending, pendingContext.colors),
      );

      await tester.scrollUntilVisible(
        _sectionHeader('Abandonado'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(_sectionHeader('Abandonado'), findsOneWidget);
    },
  );
}
