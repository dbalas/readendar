import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/event_card_compact.dart';
import 'package:readendar/core/widgets/event_icon.dart';

Widget _wrap({required Widget home}) => ProviderScope(
  child: MaterialApp(
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    locale: const Locale('es'),
    home: home,
  ),
);

void main() {
  testWidgets('renders event data with book title and author', (tester) async {
    await tester.pumpWidget(
      _wrap(
        home: const Scaffold(
          body: EventCardCompact(
            title: 'Page milestone',
            type: EventType.pageMilestone,
            subtitle: '12/6',
            bookTitle: 'Pedro Paramo',
            bookAuthor: 'Juan Rulfo',
          ),
        ),
      ),
    );

    expect(find.text('Page milestone'), findsOneWidget);
    expect(find.text('12/6'), findsOneWidget);
    expect(find.text('Pedro Paramo'), findsWidgets);
    expect(find.text('Juan Rulfo'), findsOneWidget);

    final bookTitleLeft = tester.getTopLeft(find.text('Pedro Paramo').last);
    final eventTitleLeft = tester.getTopLeft(find.text('Page milestone'));
    expect(bookTitleLeft.dx, lessThan(eventTitleLeft.dx));
  });
}
