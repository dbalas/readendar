import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_vector_icon.dart';

void main() {
  testWidgets('chapter chevrons paint on iOS without Lucide glyphs', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: const Scaffold(
            body: Row(
              children: [
                ReadingChapterChevron(),
                ReadingChapterChevronsUpDown(),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('readingChapterChevron')), findsOneWidget);
      expect(
        find.byKey(const Key('readingChapterChevronsUpDown')),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.chevronRight), findsNothing);
      expect(find.byIcon(LucideIcons.chevronsUpDown), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = previous;
    }
  });
}
