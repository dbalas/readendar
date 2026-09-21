import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/library_screen.dart';

void main() {
  testWidgets('library load failure shows ErrorRetry instead of empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith(
            (ref) async => throw const FailureException(NetworkFailure()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(
      find.text(
        'Tu biblioteca está vacía. Añade tu primer libro para empezar.',
      ),
      findsNothing,
    );
  });
}
