import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/stats/user_stats_screen.dart';

void main() {
  testWidgets('stats load failure shows ErrorRetry, not the empty taste copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userStatsProvider.overrideWith(
            (ref) async => throw const FailureException(NetworkFailure()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const UserStatsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(
      find.text('Aún no hay suficiente historial de lectura.'),
      findsNothing,
    );
  });

  testWidgets(
    'page activity load failure shows ErrorRetry, not the empty taste copy',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userPageStatsProvider.overrideWith(
              (ref, query) async =>
                  throw const FailureException(NetworkFailure()),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: UserPageActivityScreen(initialStats: _pageActivityStats()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorRetry), findsOneWidget);
      expect(
        find.text('Aún no hay suficiente historial de lectura.'),
        findsNothing,
      );
    },
  );
}

UserStats _pageActivityStats() => UserStats.fromJson({
  'summary': <String, dynamic>{},
  'overview': <String, dynamic>{'year': 2026},
  'activity': <String, dynamic>{},
  'pageActivity': <String, dynamic>{
    'granularity': 'month',
    'offset': 0,
    'from': '2026-09-01',
    'to': '2026-09-30',
    'totalPages': 10,
    'todayPages': 0,
    'averagePages': 0,
    'activeBuckets': 0,
    'activeDays': 0,
    'buckets': <dynamic>[],
  },
  'taste': <String, dynamic>{},
});
