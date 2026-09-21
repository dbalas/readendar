import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/app_locales.dart';
import 'package:readendar/core/l10n/book_categories.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';

void main() {
  test('every supported locale resolves every canonical category', () async {
    expect(bookCategoryCodes, hasLength(30));
    for (final appLocale in kAppLocales) {
      final l10n = await AppL10n.delegate.load(appLocale.locale);
      for (final code in bookCategoryCodes) {
        final label = bookCategoryLabel(l10n, code);
        expect(label.trim(), isNotEmpty, reason: '${appLocale.tag}:$code');
        expect(label, isNot(code), reason: '${appLocale.tag}:$code');
      }
    }
  });

  test('unknown codes and legacy raw-only payloads never leak provider text',
    () async {
      final l10n = await AppL10n.delegate.load(const Locale('es'));
      expect(
        bookCategoryLabel(l10n, 'future_category'),
        l10n.bookCategoryOther,
      );
      expect(
        bookCategoryLabel(l10n, 'mystery'),
        l10n.bookCategoryMysteryCrime,
      );
      expect(
        bookCategoryLabels(
          l10n,
          const <String>[],
          hasRawCategories: true,
        ),
        [l10n.bookCategoryOther],
      );
    },
  );
}
