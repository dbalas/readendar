import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_hub_screen.dart';

void main() {
  test(
    'archive pagination discards responses from an old filter generation',
    () {
      expect(
        readingChapterArchiveRequestIsCurrent(
          requestGeneration: 2,
          currentGeneration: 3,
          requestFilter: 'month',
          currentFilter: 'year',
        ),
        isFalse,
      );
      expect(
        readingChapterArchiveRequestIsCurrent(
          requestGeneration: 3,
          currentGeneration: 3,
          requestFilter: 'year',
          currentFilter: 'year',
        ),
        isTrue,
      );
    },
  );
}
