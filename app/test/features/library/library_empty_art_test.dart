import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/library_empty_art.dart';
import 'package:readendar/features/library/library_screen.dart';

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
  testWidgets('library empty art uses EmptyArtBackdrop and library cues', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const LibraryEmptyArt()));
    await tester.pumpAndSettle();

    final backdrop = tester.widget<EmptyArtBackdrop>(
      find.byType(EmptyArtBackdrop),
    );
    expect(backdrop.height, 208);
    expect(find.byIcon(LucideIcons.plus), findsOneWidget);
    // Cover fan + add cue — no bare library/book/calendar glyphs.
    expect(find.byIcon(LucideIcons.library), findsNothing);
    expect(find.byIcon(LucideIcons.book), findsNothing);
    expect(find.byIcon(LucideIcons.calendarDays), findsNothing);
    expect(find.byIcon(LucideIcons.users), findsNothing);
  });

  testWidgets('library empty art composes via entrance animation', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const LibraryEmptyArt()));
    // Mid-entrance: art is mounted but not yet settled.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LibraryEmptyArt), findsOneWidget);
    expect(find.byType(EmptyArtBackdrop), findsOneWidget);

    await tester.pumpAndSettle();
    // After compose, the + cue is fully present.
    expect(find.byIcon(LucideIcons.plus), findsOneWidget);
  });

  testWidgets('empty library screen shows LibraryEmptyArt', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => const <Book>[]),
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

    expect(find.byType(LibraryEmptyArt), findsOneWidget);
    expect(find.byType(EmptyArtBackdrop), findsOneWidget);
    // Bare icon fallback must not show when illustration is set.
    expect(find.byIcon(LucideIcons.book), findsNothing);
  });
}
