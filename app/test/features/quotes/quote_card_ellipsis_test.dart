import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/widgets/rd_list_item_actions.dart';
import 'package:readendar/core/widgets/rd_menu.dart';
import 'package:readendar/features/quotes/quote_card.dart';

import 'quotes_test_utils.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('es'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: Scaffold(
    body: SizedBox(width: 390, child: child),
  ),
);

String _longBody() => List.generate(
  20,
  (i) => 'Palabra número $i en una anotación muy larga',
).join(' ');

void main() {
  Future<void> pumpCard(
    WidgetTester tester, {
    required String text,
    AnnotationCategory category = AnnotationCategory.quote,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        QuoteCard(
          quote: testQuote(text: text, category: category),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Text _bodyText(WidgetTester tester, {required String needle}) =>
      tester.widget<Text>(
        find
            .descendant(
              of: find.byType(QuoteCard),
              matching: find.byWidgetPredicate(
                (w) => w is Text && (w.data?.contains(needle) ?? false),
              ),
            )
            .first,
      );

  void expectClampedPreview(Text preview, {required String fullBody}) {
    expect(preview.maxLines, 3);
    expect(preview.overflow, TextOverflow.ellipsis);
    expect(preview.data?.length, lessThan(fullBody.length + 4));
  }

  testWidgets('quote category preview ends with ellipsis', (tester) async {
    final body = _longBody();
    await pumpCard(tester, text: body);
    expectClampedPreview(_bodyText(tester, needle: 'Palabra'), fullBody: body);
  });

  testWidgets('note category preview ends with ellipsis', (tester) async {
    final body = _longBody();
    await pumpCard(
      tester,
      text: body,
      category: AnnotationCategory.note,
    );
    expectClampedPreview(_bodyText(tester, needle: 'Palabra'), fullBody: body);
  });

  testWidgets('multiline note preview ends with ellipsis', (tester) async {
    final body = List.generate(
      12,
      (i) => 'Línea $i de una nota larga.',
    ).join('\n');
    await pumpCard(
      tester,
      text: body,
      category: AnnotationCategory.theory,
    );
    expectClampedPreview(_bodyText(tester, needle: 'Línea'), fullBody: body);
  });

  testWidgets('swipe row preview ends with ellipsis', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        RdListItemActions(
          items: const [
            RdMenuItem(value: 'delete', label: 'Eliminar'),
          ],
          onSelected: (_) {},
          child: QuoteCard(
            quote: testQuote(text: _longBody()),
            card: false,
            accentFrame: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expectClampedPreview(
      _bodyText(tester, needle: 'Palabra'),
      fullBody: _longBody(),
    );
  });
}
