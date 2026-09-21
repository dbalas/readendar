/// Policy version stamped on the local guest profile.
const currentTermsVersion = '2026-08-01';

/// Privacy policy on readendar.com (Spanish copy).
Uri privacyPolicyUrl(String localeCode) => _legalUrl('privacy');

/// Terms of use on readendar.com. Same path scheme as [privacyPolicyUrl].
Uri termsOfUseUrl(String localeCode) => _legalUrl('terms');

Uri _legalUrl(String slug) {
  return Uri.parse('https://readendar.com/legal/$slug');
}
