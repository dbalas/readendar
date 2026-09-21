import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/app_locales.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/features/library/book_binding_display.dart';

void main() {
  test('every supported locale translates every canonical binding', () async {
    expect(bookBindingCodes, hasLength(18));
    final missing = <String>[];
    for (final appLocale in kAppLocales) {
      final l10n = await AppL10n.delegate.load(appLocale.locale);
      for (final code in bookBindingCodes) {
        final label = bookBindingDisplayName(l10n, code);
        expect(label.trim(), isNotEmpty, reason: '${appLocale.tag}:$code');
        expect(label, isNot(code), reason: '${appLocale.tag}:$code');
        if (canonicalBookBindingCode(label) != code) {
          missing.add('${appLocale.tag}:$code="$label"');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join(', '));
  });

  test(
    'catalog English and localized aliases share one storage term',
    () async {
      final es = await AppL10n.delegate.load(const Locale('es'));

      expect(bookBindingDisplayName(es, 'Hardcover'), 'Tapa dura');
      expect(bookBindingDisplayName(es, ' tapa dura '), 'Tapa dura');
      expect(bookBindingDisplayName(es, 'hardback'), 'Tapa dura');
      expect(canonicalBookBindingStorage('Tapa dura'), 'Hardcover');
      expect(canonicalBookBindingStorage(' paperback '), 'Paperback');
      expect(canonicalBookBindingStorage('Kindle Edition'), 'Kindle Edition');
    },
  );

  test('Turtleback and unknown-binding strings match catalog options', () async {
    final es = await AppL10n.delegate.load(const Locale('es'));
    expect(canonicalBookBindingCode('Turtleback'), 'turtleback');
    expect(canonicalBookBindingStorage('Turtleback'), 'Turtleback');
    expect(bookBindingDisplayName(es, 'Turtleback'), 'Turtleback');
    expect(canonicalBookBindingCode('Unknown Binding'), 'unknownBinding');
    expect(canonicalBookBindingStorage('Unknown Binding'), 'Unknown Binding');
  });

  test('unrecognized catalog bindings stay visible verbatim', () async {
    final es = await AppL10n.delegate.load(const Locale('es'));
    expect(bookBindingDisplayName(es, 'Pop-up'), 'Pop-up');
    expect(canonicalBookBindingCode('Pop-up'), isNull);
    expect(canonicalBookBindingStorage('Pop-up'), 'Pop-up');
    expect(canonicalBookBindingStorage('   '), isNull);
  });
}
