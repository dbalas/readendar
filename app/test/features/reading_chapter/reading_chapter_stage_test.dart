import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_stage.dart';

void main() {
  testWidgets(
    'story progress makes every chapter position directly reachable',
    (
      tester,
    ) async {
      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: ReadingChapterStoryProgress(
              current: 1,
              total: 4,
              onSelect: (value) => selected = value,
            ),
          ),
        ),
      );

      expect(find.byType(GestureDetector), findsNWidgets(4));
      await tester.tap(find.byType(GestureDetector).at(3));
      expect(selected, 3);
    },
  );

  testWidgets('annual stage keeps content readable on a quiet canvas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: ReadingChapterStage(
            child: Center(child: Text('Chapter content')),
          ),
        ),
      ),
    );

    expect(find.text('Chapter content'), findsOneWidget);
  });
}
