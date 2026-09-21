import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/utils/progress_display.dart';

void main() {
  group('effectiveProgressPercent', () {
    test('derives from pages when total is known, ignoring stale percentage', () {
      expect(
        effectiveProgressPercent(
          currentPage: 51,
          currentPercentage: 20,
          pageCount: 120,
        ),
        43,
      );
    });

    test('uses explicit percentage when pages cannot derive it', () {
      expect(
        effectiveProgressPercent(currentPercentage: 20),
        20,
      );
      expect(
        effectiveProgressPercent(
          currentPage: 51,
          currentPercentage: 20,
        ),
        20,
      );
    });

    test('returns null when nothing measurable is present', () {
      expect(effectiveProgressPercent(), isNull);
      expect(effectiveProgressPercent(currentPage: 10, pageCount: 0), isNull);
    });

    test('clamps derived and explicit values to 0–100', () {
      expect(
        effectiveProgressPercent(currentPage: 150, pageCount: 100),
        100,
      );
      expect(effectiveProgressPercent(currentPercentage: 140), 100);
      expect(effectiveProgressPercent(currentPercentage: -5), 0);
    });
  });

  group('shouldShowProgressPercentLabel', () {
    test('shows percent when derived from page + total', () {
      expect(
        shouldShowProgressPercentLabel(
          currentPage: 51,
          currentPercentage: 20,
          pageCount: 120,
        ),
        isTrue,
      );
    });

    test('shows percent when only percentage is set', () {
      expect(
        shouldShowProgressPercentLabel(currentPercentage: 20),
        isTrue,
      );
    });

    test('hides percent when page is set without a total', () {
      expect(
        shouldShowProgressPercentLabel(
          currentPage: 51,
          currentPercentage: 20,
        ),
        isFalse,
      );
    });
  });
}
