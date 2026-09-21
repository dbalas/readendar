import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/widgets/cover_badge.dart';
import 'package:readendar/features/library/rating_sheet.dart';

void main() {
  group('fmtRating', () {
    test('drops the trailing .0 but keeps halves', () {
      expect(fmtRating(4), '4');
      expect(fmtRating(5), '5');
      expect(fmtRating(4.5), '4.5');
      expect(fmtRating(0.5), '0.5');
    });
  });

  group('starIconForRating', () {
    test('picks full / half / empty per slot', () {
      // value 3.5 → stars 1-3 full, star 4 half, star 5 empty.
      expect(starIconForRating(3.5, 1), Icons.star_rounded);
      expect(starIconForRating(3.5, 3), Icons.star_rounded);
      expect(starIconForRating(3.5, 4), Icons.star_half_rounded);
      expect(starIconForRating(3.5, 5), Icons.star_outline_rounded);
    });
  });

  group('ratingFromOffset', () {
    const size = 40.0;
    test('left half of a star yields i-0.5, right half yields i', () {
      expect(ratingFromOffset(5, size), 0.5); // star1 left
      expect(ratingFromOffset(30, size), 1.0); // star1 right
      expect(ratingFromOffset(40 * 3 + 5, size), 3.5); // star4 left
      expect(ratingFromOffset(40 * 3 + 30, size), 4.0); // star4 right
      expect(ratingFromOffset(40 * 4 + 35, size), 5.0); // star5 right
    });
    test('clamps to 0–5.0 outside the row', () {
      expect(ratingFromOffset(-10, size), 0.0);
      expect(ratingFromOffset(99999, size), 5.0);
    });
  });

  testWidgets('HalfStarPicker maps a tap to a half-star', (tester) async {
    double? last;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HalfStarPicker(value: 0, size: 40, onChanged: (v) => last = v),
          ),
        ),
      ),
    );
    final tl = tester.getTopLeft(find.byType(HalfStarPicker));
    await tester.tapAt(tl + const Offset(40 * 3 + 10, 20)); // star 4, left → 3.5
    expect(last, 3.5);
  });

  testWidgets('dragging across the row scrubs the rating up to 5', (
    tester,
  ) async {
    final values = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: HalfStarPicker(value: 0, size: 40, onChanged: values.add),
          ),
        ),
      ),
    );
    final tl = tester.getTopLeft(find.byType(HalfStarPicker));
    await tester.dragFrom(tl + const Offset(5, 20), const Offset(190, 0));
    expect(values, isNotEmpty);
    expect(values.last, 5.0);
  });
}
