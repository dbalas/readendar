import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/app_locales.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';

void main() {
  test('kAppLocales matches generated AppL10n.supportedLocales', () {
    final generated = AppL10n.supportedLocales.map(localeToTag).toSet();
    expect(
      kSupportedLocaleTags,
      equals(generated),
      reason:
          'app_locales.dart must stay in sync with the ARB files / generated '
          'supportedLocales. Add or remove an .arb file and re-run gen-l10n.',
    );
  });

  test('tags round-trip through Locale', () {
    for (final a in kAppLocales) {
      expect(localeToTag(a.locale), a.tag);
      expect(localeToTag(localeFromTag(a.tag)), a.tag);
    }
  });

  test('resolveSupportedTag is Spanish-only', () {
    expect(resolveSupportedTag(const Locale('es')), 'es');
    expect(resolveSupportedTag(const Locale('es', 'ES')), 'es');
    expect(resolveSupportedTag(const Locale('es', 'MX')), 'es');
    expect(resolveSupportedTag(const Locale('en')), isNull);
    expect(resolveSupportedTag(const Locale('en', 'US')), isNull);
    expect(resolveSupportedTag(const Locale('pt', 'BR')), isNull);
    expect(resolveSupportedTag(const Locale('ja')), isNull);
  });
}
