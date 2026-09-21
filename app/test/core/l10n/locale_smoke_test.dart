import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/l10n/localization_delegates.dart';
import 'package:readendar/core/utils/date_format.dart';

/// Smoke test: every supported locale must resolve, format dates/numbers, and
/// evaluate its ICU plural + placeholder messages without throwing. The
/// `app_locales_test` guards the locale *set*; this guards that each locale
/// actually *renders* — catching a malformed translation (bad placeholder,
/// broken plural branch, missing intl data for a region) that a key-count check
/// would miss.
void main() {
  for (final locale in AppL10n.supportedLocales) {
    testWidgets('locale $locale resolves and formats without throwing', (
      tester,
    ) async {
      Object? caught;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: readendarLocalizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) {
              try {
                final l = AppL10n.of(context);
                FlutterQuillLocalizations.of(context)!.bold;
                // Exercise: plain getter, a String-placeholder message, and an
                // ICU plural across its boundary cases.
                l.appName;
                l.greetingMorning('Marina');
                for (final n in [0, 1, 2, 42]) {
                  l.quotesCount(n);
                }
                // Region-aware date + number formatting for this exact locale.
                formatMediumDate(context, DateTime(2026, 6, 15));
                formatDayMonth(context, DateTime(2026, 6, 15));
              } catch (e) {
                caught = e;
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(caught, isNull, reason: 'locale $locale threw: $caught');
    });
  }
}
