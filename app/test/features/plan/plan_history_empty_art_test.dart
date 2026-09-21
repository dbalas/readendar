import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/features/plan/presentation/plan_history_empty_art.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('es'),
  theme: buildLightTheme(),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: Scaffold(
    body: EmptyState(
      illustration: child,
      message: 'Placeholder',
    ),
  ),
);

void main() {
  testWidgets('plan history empty art uses EmptyArtBackdrop and plan cues', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const PlanHistoryEmptyArt()));
    await tester.pumpAndSettle();

    final backdrop = tester.widget<EmptyArtBackdrop>(
      find.byType(EmptyArtBackdrop),
    );
    expect(backdrop.height, 196);
    expect(find.byIcon(LucideIcons.calendarClock), findsOneWidget);
    expect(find.byIcon(LucideIcons.calendarRange), findsOneWidget);
  });
}
