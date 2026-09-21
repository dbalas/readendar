import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/widgets/month_calendar.dart';

void main() {
  Future<int> firstDow(WidgetTester tester, Locale locale) async {
    late int value;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: [locale],
        home: Builder(
          builder: (context) {
            value = firstDayOfWeekFor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return value;
  }

  testWidgets('firstDayOfWeekFor honors locale, Monday-first for pt-Portugal', (
    tester,
  ) async {
    // 1 = Monday, 0 = Sunday.
    expect(await firstDow(tester, const Locale('es')), 1);
    expect(await firstDow(tester, const Locale('en', 'GB')), 1);
    expect(await firstDow(tester, const Locale('nl')), 1);
    expect(await firstDow(tester, const Locale('en', 'US')), 0);
    expect(await firstDow(tester, const Locale('en', 'CA')), 0);
    // Override: region-less pt (our "Português (Portugal)") is Monday-first,
    // even though Flutter/CLDR defaults region-less pt to Sunday.
    expect(await firstDow(tester, const Locale('pt')), 1);
    // Brazilian Portuguese keeps its correct Sunday-first value.
    expect(await firstDow(tester, const Locale('pt', 'BR')), 0);
  });
}
