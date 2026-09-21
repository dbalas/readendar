import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/cover_badge.dart';
import 'package:readendar/core/widgets/month_calendar.dart';

ReadingEvent _event({required String id, String type = 'deadline'}) =>
    ReadingEvent(
      id: id,
      ownerType: OwnerType.user,
      ownerId: 'user-1',
      type: type,
      title: id,
      dateLocal: DateTime(2026, 8, 3),
      status: EventStatus.active,
    );

Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    locale: const Locale('es'),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('personal event without book falls back to a type dot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        DayEventMarkers(
          events: [_event(id: 'solo')],
          eventContext: EventRenderContext(
            personalBooks: const [],
          ),
        ),
      ),
    );

    expect(find.byType(BadgedCover), findsNothing);
  });
}
