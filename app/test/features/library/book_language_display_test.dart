import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/app_locales.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/features/library/book_language_display.dart';

void main() {
  test('every supported locale translates every canonical language', () async {
    for (final appLocale in kAppLocales) {
      final l10n = await AppL10n.delegate.load(appLocale.locale);
      for (final code in bookLanguageCodes) {
        final label = bookLanguageDisplayName(l10n, code);
        expect(label.trim(), isNotEmpty, reason: '${appLocale.tag}:$code');
        expect(
          label.toLowerCase(),
          isNot(code),
          reason: '${appLocale.tag}:$code fell through to the raw code',
        );
      }
    }
  });

  test('catalog language codes and names share one ISO 639-1 storage value', () {
    const cases = <String, String>{
      'es': 'es',
      'spa': 'es',
      'Spanish': 'es',
      'español': 'es',
      'en': 'en',
      'eng': 'en',
      'English': 'en',
      'en-GB': 'en',
      'en_US': 'en',
      'fra': 'fr',
      'fre': 'fr',
      'French': 'fr',
      'ger': 'de',
      'deu': 'de',
      'jpn': 'ja',
      'Japanese': 'ja',
      'chi': 'zh',
      'zho': 'zh',
      'nor': 'nb',
      'no': 'nb',
      'dut': 'nl',
      'nld': 'nl',
      'cat': 'ca',
      'fil': 'tl',
    };
    for (final entry in cases.entries) {
      expect(
        canonicalBookLanguageCode(entry.key),
        entry.value,
        reason: entry.key,
      );
      expect(
        canonicalBookLanguageStorage(entry.key),
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('selector sorts accented labels with their base letter', () async {
    final es = await AppL10n.delegate.load(const Locale('es'));
    final labels = [
      for (final code in bookLanguageCodesSorted(es))
        bookLanguageDisplayName(es, code),
    ];
    expect(labels, contains('Árabe'));
    expect(labels.indexOf('Árabe'), lessThan(labels.indexOf('Español')));
    expect(labels.indexOf('Afrikáans'), lessThan(labels.indexOf('Árabe')));
    expect(labels.indexOf('Árabe'), lessThan(labels.indexOf('Vietnamita')));
    expect(labels.last, isNot('Árabe'));
  });

  test('unknown catalog languages stay visible verbatim', () async {
    final es = await AppL10n.delegate.load(const Locale('es'));
    expect(bookLanguageDisplayName(es, 'zz'), 'zz');
    expect(canonicalBookLanguageCode('zz'), isNull);
    expect(canonicalBookLanguageStorage('zz'), 'zz');
    expect(canonicalBookLanguageStorage('   '), isNull);
  });
}
