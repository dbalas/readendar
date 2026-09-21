/// Maps an app locale tag to an iTunes Lookup `country` storefront.
///
/// Apple's lookup is storefront-based, not language-based. Tags follow the
/// Fastlane asset → App Store listing map so What's New matches uploaded notes.
String itunesCountryForLocaleTag(String tag) {
  final normalized = tag.trim();
  if (normalized.isEmpty) return 'us';
  return _countryByTag[normalized] ??
      _countryByTag[normalized.split('-').first] ??
      'us';
}

/// iTunes Lookup is storefront-based. Some app languages are not what that
/// country returns (Catalan on ES, Canadian French on CA).
bool itunesNotesTrustedForLocaleTag(String tag) {
  final normalized = tag.trim();
  return normalized != 'ca' && normalized.toLowerCase() != 'fr-ca';
}

const Map<String, String> _countryByTag = {
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
