import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/app_update/app_update_storefront.dart';

void main() {
  test('maps app locale tags to iTunes storefront countries', () {
    const expected = {
      'es': 'es',
      'es-419': 'mx',
      'ca': 'es',
      'en': 'us',
      'en-US': 'us',
      'en-GB': 'gb',
      'en-AU': 'au',
      'en-CA': 'ca',
      'pt': 'pt',
      'pt-BR': 'br',
      'fr': 'fr',
      'fr-CA': 'ca',
      'de': 'de',
      'de-AT': 'de',
      'de-CH': 'de',
      'it': 'it',
      'nl': 'nl',
      'nl-BE': 'nl',
      'pl': 'pl',
      'tr': 'tr',
      'sv': 'se',
      'da': 'dk',
      'nb': 'no',
      'fi': 'fi',
    };
    for (final e in expected.entries) {
      expect(itunesCountryForLocaleTag(e.key), e.value, reason: e.key);
    }
  });

  test('unknown tags fall back to us, then base language', () {
    expect(itunesCountryForLocaleTag(''), 'us');
    expect(itunesCountryForLocaleTag('ja'), 'us');
    expect(itunesCountryForLocaleTag('pt-AO'), 'pt');
  });

  test('storefront notes are untrusted when lookup language cannot match', () {
    expect(itunesNotesTrustedForLocaleTag('ca'), isFalse);
    expect(itunesNotesTrustedForLocaleTag('fr-CA'), isFalse);
    expect(itunesNotesTrustedForLocaleTag('fr-ca'), isFalse);
    expect(itunesNotesTrustedForLocaleTag('es'), isTrue);
    expect(itunesNotesTrustedForLocaleTag('en'), isTrue);
    expect(itunesNotesTrustedForLocaleTag('fr'), isTrue);
  });
}
