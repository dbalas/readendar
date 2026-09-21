import 'package:flutter/widgets.dart';

/// Single source of truth for the app's supported locales and BCP-47 tag ⇄
/// [Locale] conversion. The product ships Spanish only, worldwide. There is no
/// in-app language picker; every device resolves to `es`.
///
/// Tags are canonical BCP-47: language subtag lower-case, region subtag
/// upper-case.
///
/// Keep this list in sync with the generated `AppL10n.supportedLocales`
/// (asserted by `test/core/l10n/app_locales_test.dart`).
class AppLocale {
  const AppLocale(this.locale, this.tag);

  /// The Flutter [Locale] (with optional country subtag).
  final Locale locale;

  /// Canonical BCP-47 tag, e.g. `es`.
  final String tag;
}

/// The supported locales, in display order.
const List<AppLocale> kAppLocales = <AppLocale>[
  AppLocale(Locale('es'), 'es'),
];

/// All supported canonical tags.
final Set<String> kSupportedLocaleTags = <String>{
  for (final a in kAppLocales) a.tag,
};

/// Canonical BCP-47 tag for a [Locale] (language lower, region upper).
String localeToTag(Locale l) {
  final c = l.countryCode;
  if (c != null && c.isNotEmpty) {
    return '${l.languageCode.toLowerCase()}-${c.toUpperCase()}';
  }
  return l.languageCode.toLowerCase();
}

/// Parses a BCP-47 tag into a [Locale]. Does not validate against the set.
Locale localeFromTag(String tag) {
  final parts = tag.split('-');
  if (parts.length >= 2 && parts[1].isNotEmpty) {
    return Locale(parts[0].toLowerCase(), parts[1].toUpperCase());
  }
  return Locale(parts[0].toLowerCase());
}

/// Resolves a device [Locale] to the best supported tag: exact region match,
/// then base language, else `null` (caller picks the ultimate fallback, `es`).
String? resolveSupportedTag(Locale device) {
  final lang = device.languageCode.toLowerCase();
  final full = localeToTag(device);
  if (kSupportedLocaleTags.contains(full)) return full;
  if (kSupportedLocaleTags.contains(lang)) return lang;
  return null;
}
