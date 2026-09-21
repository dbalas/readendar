import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_models.dart';
import 'package:readendar/features/widget/widgets_screen.dart';

import '../quotes/quotes_test_utils.dart';

void main() {
  testWidgets('uses the shared editorial title system', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          widgetSummaryProvider.overrideWith(
            (ref) async => const WidgetSummary(readingBooks: [], events: []),
          ),
          quoteRepoProvider.overrideWithValue(FakeQuoteRepository([])),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const WidgetsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('widgetsEditorialTitle')), findsOneWidget);
    expect(find.byKey(const Key('widgetsSectionTitle')), findsNWidgets(3));
  });
}
