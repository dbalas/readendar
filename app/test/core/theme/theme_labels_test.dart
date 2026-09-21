import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/theme_labels.dart';

void main() {
  test('theme names stay compact in every supported locale', () {
    final violations = <String>[];
    for (final locale in AppL10n.supportedLocales) {
      final l = lookupAppL10n(locale);
      for (final definition in ReadendarThemes.all) {
        final label = readendarThemeLabel(l, definition.id);
        if (label.runes.length > 10) {
          violations.add('${definition.id.wire} in $locale: "$label"');
        }
        expect(label, label.trim(), reason: '${definition.id.wire} in $locale');
        expect(
          label.contains('\n'),
          isFalse,
          reason: '${definition.id.wire} in $locale',
        );
      }
    }
    expect(
      violations,
      isEmpty,
      reason:
          'Theme names must stay at or below ten characters:\n'
          '${violations.join('\n')}',
    );
  });
}
