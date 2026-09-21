import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/widget/widget_models.dart';

void main() {
  group('WidgetSummary.fromJson', () {
    test('parses books + events and derives isEmpty', () {
      final s = WidgetSummary.fromJson({
        'readingBooks': [
          {
            'id': 'b1',
            'title': 'Dune',
            'author': 'Herbert',
            'coverUrl': 'c',
            'progressPct': 42,
            'currentPage': 120,
            'pageCount': 300,
            'currentChapter': 7,
            'chapterCount': 20,
          },
          {'id': 'b2', 'title': 'X', 'author': '', 'coverUrl': ''},
        ],
        'events': [
          {
            'id': 'e1',
            'type': 'finish',
            'dateLocal': '2026-07-02',
            'bookId': 'b1',
            'bookTitle': 'Dune',
            'timeLocal': '18:00',
            'tz': 'Europe/Madrid',
          },
        ],
      });
      expect(s.isEmpty, isFalse);
      expect(s.readingBooks, hasLength(2));
      expect(s.readingBooks.first.progressPct, 42);
      expect(s.readingBooks.first.currentPage, 120);
      expect(s.readingBooks.first.pageCount, 300);
      expect(s.readingBooks.first.currentChapter, 7);
      expect(s.readingBooks.first.chapterCount, 20);
      expect(s.readingBooks[1].progressPct, isNull);
      expect(s.events.single.timeLocal, '18:00');
      expect(s.events.single.tz, 'Europe/Madrid');
    });

    test('tolerates missing/empty payload', () {
      expect(WidgetSummary.fromJson(const {}).isEmpty, isTrue);
      final s = WidgetSummary.fromJson({
        'readingBooks': null,
        'events': 'garbage',
      });
      expect(s.isEmpty, isTrue);
    });

    test('parses hasMore + event status (default active)', () {
      final s = WidgetSummary.fromJson({
        'hasMore': true,
        'events': [
          {
            'id': 'e1',
            'type': 'page_milestone',
            'dateLocal': '2026-07-02',
            'status': 'completed',
          },
          {'id': 'e2', 'type': 'page_milestone', 'dateLocal': '2026-07-03'},
        ],
      });
      expect(s.hasMore, isTrue);
      expect(s.events[0].status, 'completed');
      expect(s.events[0].isCompleted, isTrue);
      expect(s.events[1].status, 'active'); // default when absent
      expect(s.events[1].isCompleted, isFalse);
    });

    test('hasMore defaults to false', () {
      expect(
        WidgetSummary.fromJson(const {'events': <dynamic>[]}).hasMore,
        isFalse,
      );
    });

    test('toJson round-trips the native cache shape', () {
      const original = WidgetSummary(
        readingBooks: [
          WidgetBook(
            id: 'b1',
            title: 'Dune',
            author: 'Herbert',
            coverUrl: 'c',
            progressPct: 42,
            currentPage: 120,
            pageCount: 300,
          ),
        ],
        events: [
          WidgetEvent(
            id: 'e1',
            type: 'finish',
            dateLocal: '2026-07-02',
            bookId: 'b1',
            bookTitle: 'Dune',
            status: 'completed',
          ),
        ],
        hasMore: true,
      );
      final round = WidgetSummary.fromJson(original.toJson());
      expect(round.hasMore, isTrue);
      expect(round.readingBooks.single.id, 'b1');
      expect(round.readingBooks.single.progressPct, 42);
      expect(round.readingBooks.single.currentPage, 120);
      expect(round.events.single.status, 'completed');
      expect(round.events.single.bookTitle, 'Dune');
    });
  });

  test('WidgetSession.fromJson parses the token pair', () {
    final w = WidgetSession.fromJson({
      'userId': 'u1',
      'accessToken': 'a',
      'refreshToken': 'r',
    });
    expect(w.userId, 'u1');
    expect(w.accessToken, 'a');
    expect(w.refreshToken, 'r');
  });

  group('WidgetQuotesPayload (wdg_quotes_cache contract)', () {
    test('round-trips through JSON with exact field names', () {
      final payload = WidgetQuotesPayload(
        fetchedAt: DateTime.utc(2026, 7, 2, 10),
        quotes: const [
          WidgetQuote(
            id: 'q1',
            text: 'El mundo era tan reciente',
            page: 12,
            favorite: true,
            bookId: 'b1',
            bookTitle: 'Cien años de soledad',
            bookAuthor: 'Gabriel García Márquez',
            bookCoverUrl: 'https://covers/x.jpg',
          ),
          WidgetQuote(
            id: 'q2',
            text: 'sin ancla',
            bookId: 'b2',
            bookTitle: 'Pedro Páramo',
            bookAuthor: 'Juan Rulfo',
          ),
        ],
      );
      final json = payload.toJson();
      // Exact key names are the Swift/Kotlin parse contract.
      expect(json.keys, containsAll(['fetchedAt', 'quotes']));
      final q1 = (json['quotes'] as List).first as Map<String, dynamic>;
      expect(
        q1.keys,
        containsAll([
          'id',
          'text',
          'page',
          'favorite',
          'bookId',
          'bookTitle',
          'bookAuthor',
          'bookCoverUrl',
        ]),
      );
      final q2 = (json['quotes'] as List)[1] as Map<String, dynamic>;
      expect(q2.containsKey('page'), isFalse, reason: 'null page omitted');
      expect(q2.containsKey('bookCoverUrl'), isFalse);

      final back = WidgetQuotesPayload.fromJson(json);
      expect(back.fetchedAt, payload.fetchedAt);
      expect(back.quotes, hasLength(2));
      expect(back.quotes.first.text, 'El mundo era tan reciente');
      expect(back.quotes.first.page, 12);
      expect(back.quotes.first.favorite, isTrue);
      expect(back.quotes[1].page, isNull);
      expect(back.quotes[1].bookCoverUrl, '');
    });

    test('tolerates junk / missing fields', () {
      final p = WidgetQuotesPayload.fromJson(const {
        'quotes': [
          {'id': 'q1'},
          'junk',
        ],
      });
      expect(p.quotes, hasLength(1));
      expect(p.quotes.first.favorite, isFalse);
    });

    test('remaps annotation DTO fields onto widget quote cache', () {
      final p = WidgetQuotesPayload.fromJson(const {
        'annotations': [
          {
            'id': 'a1',
            'body': 'from body',
            'favorite': true,
            'commentary': 'aside',
            'bookId': 'b1',
            'bookTitle': 'Dune',
            'bookAuthor': 'Herbert',
          },
        ],
      });
      expect(p.quotes.single.text, 'from body');
      expect(p.quotes.single.favorite, isTrue);
      expect(p.quotes.single.note, 'aside');
    });

    test('does not treat pin as favorite', () {
      final p = WidgetQuotesPayload.fromJson(const {
        'annotations': [
          {
            'id': 'a1',
            'body': 'from body',
            'pinned': true,
            'bookId': 'b1',
            'bookTitle': 'Dune',
            'bookAuthor': 'Herbert',
          },
        ],
      });
      expect(p.quotes.single.favorite, isFalse);
    });

    test('keeps favorite false when pinned is true', () {
      final p = WidgetQuotesPayload.fromJson(const {
        'annotations': [
          {
            'id': 'a1',
            'body': 'from body',
            'pinned': true,
            'favorite': false,
            'bookId': 'b1',
            'bookTitle': 'Dune',
            'bookAuthor': 'Herbert',
          },
        ],
      });
      expect(p.quotes.single.favorite, isFalse);
    });

    test('skips non-quote annotation categories', () {
      final p = WidgetQuotesPayload.fromJson(const {
        'annotations': [
          {
            'id': 'n1',
            'body': 'a note',
            'category': 'note',
            'bookId': 'b1',
            'bookTitle': 'Dune',
            'bookAuthor': 'Herbert',
          },
          {
            'id': 'q1',
            'body': 'a quote',
            'category': 'quote',
            'favorite': true,
            'bookId': 'b1',
            'bookTitle': 'Dune',
            'bookAuthor': 'Herbert',
          },
        ],
      });
      expect(p.quotes, hasLength(1));
      expect(p.quotes.single.id, 'q1');
      expect(p.quotes.single.favorite, isTrue);
    });
  });

  group('QuotesWidgetMode', () {
    test('writes favorites and reads legacy pinned as favorites', () {
      expect(QuotesWidgetMode.favorites.wire, 'favorites');
      expect(QuotesWidgetMode.fromWire('favorites'), QuotesWidgetMode.favorites);
      expect(QuotesWidgetMode.fromWire('pinned'), QuotesWidgetMode.favorites);
      expect(
        QuotesWidgetConfig.fromJson(const {'mode': 'pinned'}).mode,
        QuotesWidgetMode.favorites,
      );
      expect(
        const QuotesWidgetConfig(mode: QuotesWidgetMode.favorites).toJson()['mode'],
        'favorites',
      );
    });
  });
}
