import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';

void main() {
  group('Quote model', () {
    test('fromJson parses all fields', () {
      final q = Quote.fromJson(const {
        'id': 'q1',
        'bookId': 'b1',
        'text': 'El mundo era tan reciente',
        'page': 12,
        'chapter': 1,
        'favorite': true,
        'createdAt': '2026-07-02T10:00:00Z',
        'updatedAt': '2026-07-02T11:00:00Z',
      });
      expect(q.id, 'q1');
      expect(q.bookId, 'b1');
      expect(q.text, 'El mundo era tan reciente');
      expect(q.page, 12);
      expect(q.chapter, 1);
      expect(q.favorite, isTrue);
      expect(q.pinned, isFalse);
    });

    test('fromJson keeps favorite independent of pinned', () {
      final pinnedOnly = Quote.fromJson(const {
        'id': 'q1',
        'bookId': 'b1',
        'text': 'pinned',
        'pinned': true,
        'favorite': false,
      });
      expect(pinnedOnly.pinned, isTrue);
      expect(pinnedOnly.favorite, isFalse);

      final favoriteOnly = Quote.fromJson(const {
        'id': 'q2',
        'bookId': 'b1',
        'text': 'starred',
        'pinned': false,
        'favorite': true,
      });
      expect(favoriteOnly.pinned, isFalse);
      expect(favoriteOnly.favorite, isTrue);
    });

    test('fromJson tolerates missing optionals', () {
      final q = Quote.fromJson(const {
        'id': 'q1',
        'bookId': 'b1',
        'text': 'sin anclas',
      });
      expect(q.page, isNull);
      expect(q.chapter, isNull);
      expect(q.favorite, isFalse);
    });

    test('toJson omits null anchors (full-replace PATCH contract)', () {
      final q = Quote(id: 'q1', bookId: 'b1', text: 't');
      final j = q.toJson();
      expect(j.containsKey('page'), isFalse);
      expect(j.containsKey('chapter'), isFalse);
      expect(j['pinned'], isFalse);
    });

    test('copyWith can clear an anchor via nullable setter', () {
      final q = Quote(id: 'q1', bookId: 'b1', text: 't', page: 10, chapter: 2);
      final cleared = q.copyWith(page: () => null);
      expect(cleared.page, isNull);
      expect(cleared.chapter, 2, reason: 'untouched fields survive');
      final kept = q.copyWith(favorite: true);
      expect(kept.page, 10, reason: 'omitting the setter keeps the value');
      expect(kept.favorite, isTrue);
    });
  });

  test('annotationBodyExceedsLimit uses the 250k-rune cap', () {
    expect(kAnnotationMaxBodyLen, 250000);
    expect(annotationBodyExceedsLimit('short'), isFalse);
    expect(
      annotationBodyExceedsLimit('ñ' * kAnnotationMaxBodyLen),
      isFalse,
    );
    expect(
      annotationBodyExceedsLimit('ñ' * (kAnnotationMaxBodyLen + 1)),
      isTrue,
    );
  });
}
