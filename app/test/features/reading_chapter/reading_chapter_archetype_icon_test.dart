import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_archetype_icon.dart';

void main() {
  test('every archetype maps to a distinct icon', () {
    final icons = readingChapterArchetypes
        .map(readingChapterArchetypeIcon)
        .toSet();
    expect(icons, hasLength(readingChapterArchetypes.length));
    expect(icons.contains(LucideIcons.orbit), isFalse);
  });

  test('unknown archetype falls back to orbit', () {
    expect(readingChapterArchetypeIcon('unknown'), LucideIcons.orbit);
  });

  test('legacy lantern maps to beacon icon', () {
    expect(
      readingChapterArchetypeIcon('lantern'),
      readingChapterArchetypeIcon('beacon'),
    );
  });
}
