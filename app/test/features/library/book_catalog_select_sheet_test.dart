import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/features/library/book_catalog_select_sheet.dart';

void main() {
  testWidgets('short lists shrink the sheet and hide search', (tester) async {
    late AppL10n l;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Builder(
          builder: (context) {
            l = AppL10n.of(context);
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showBookCatalogSelectSheet(
                    context: context,
                    title: l.metaLanguage,
                    searchable: false,
                    selected: 'spa',
                    options: const [
                      BookCatalogSelectOption(
                        value: 'spa',
                        label: 'Castellano',
                        icon: LucideIcons.globe2,
                      ),
                      BookCatalogSelectOption(
                        value: 'cat',
                        label: 'Catalán',
                        icon: LucideIcons.globe2,
                      ),
                    ],
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(RdSearchField), findsNothing);
    expect(find.text('Castellano'), findsOneWidget);
    expect(find.text('Catalán'), findsOneWidget);

    final sheetBox = tester.renderObject<RenderBox>(
      find.ancestor(
        of: find.text('Castellano'),
        matching: find.byType(Material),
      ).first,
    );
    expect(sheetBox.size.height, lessThan(320));
  });
}
