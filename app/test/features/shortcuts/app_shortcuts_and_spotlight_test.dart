import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/shortcuts/app_shortcuts.dart';
import 'package:readendar/features/spotlight/spotlight_index.dart';
import 'package:readendar/features/widget/widget_deep_link.dart';

void main() {
  group('deepLinkForShortcutType', () {
    test('maps launcher shortcut types to widget deep links', () {
      expect(
        deepLinkForShortcutType(kShortcutQuoteNew),
        const WidgetDeepLink(WidgetLinkKind.quoteNew, ''),
      );
      expect(
        deepLinkForShortcutType(kShortcutProgress),
        const WidgetDeepLink(WidgetLinkKind.progress, ''),
      );
      expect(
        deepLinkForShortcutType(kShortcutCalendar),
        const WidgetDeepLink(WidgetLinkKind.calendar, ''),
      );
      expect(deepLinkForShortcutType('unknown'), isNull);
    });

    test('icon asset names stay aligned across iOS/Android', () {
      expect(kShortcutIconQuote, 'shortcut_quote');
      expect(kShortcutIconProgress, 'shortcut_progress');
      expect(kShortcutIconCalendar, 'shortcut_calendar');
    });
  });

  group('buildSpotlightItems', () {
    test('indexes personal books and quotes only', () {
      final books = [
        Book(
          id: 'b1',
          ownerType: 'user',
          ownerId: 'u1',
          title: 'Dune',
          authors: const ['Herbert'],
          status: BookStatus.reading,
        ),
        Book(
          id: 'other-b',
          ownerType: 'legacy',
          ownerId: 'x1',
          title: 'Skip me',
          authors: const ['X'],
          status: BookStatus.reading,
        ),
      ];
      final quotes = [
        Quote(id: 'q1', bookId: 'b1', text: 'Fear is the mind-killer.'),
        Quote(id: 'q2', bookId: 'missing', text: 'Orphan quote'),
        Quote(
          id: 'n1',
          bookId: 'b1',
          text: 'Private reading note',
          category: AnnotationCategory.note,
        ),
      ];

      final items = buildSpotlightItems(books: books, quotes: quotes);
      expect(items.map((e) => e.id), ['book:b1', 'quote:q1', 'quote:q2']);
      expect(items.first.url, 'readendar://book/b1');
      expect(items[1].url, 'readendar://quote/q1');
      expect(items[1].subtitle, 'Dune');
    });
  });

  group('SpotlightIndex', () {
    test('indexItems / deleteAll hit the method channel on iOS', () async {
      final calls = <MethodCall>[];
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('readendar/spotlight'),
        (call) async {
          calls.add(call);
          if (call.method == 'indexItems') return 2;
          return null;
        },
      );

      final index = SpotlightIndex(
        channel: const MethodChannel('readendar/spotlight'),
      );
      // Force-supported path by calling channel methods directly via public API
      // when isSupported is true — on macOS test host isSupported may be false.
      if (index.isSupported) {
        final n = await index.indexItems([
          const SpotlightItem(
            id: 'book:1',
            title: 'T',
            url: 'readendar://book/1',
          ),
        ]);
        expect(n, 2);
        await index.deleteAll();
        expect(calls.map((c) => c.method), ['indexItems', 'deleteAll']);
      } else {
        expect(await index.indexItems([
          const SpotlightItem(
            id: 'book:1',
            title: 'T',
            url: 'readendar://book/1',
          ),
        ]), 0);
        await index.deleteAll();
        expect(calls, isEmpty);
      }
    });

    test('syncLibrary deletes then reindexes when supported', () async {
      final calls = <MethodCall>[];
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('readendar/spotlight'),
        (call) async {
          calls.add(call);
          if (call.method == 'indexItems') {
            final items = (call.arguments as Map)['items'] as List;
            return items.length;
          }
          return null;
        },
      );

      final index = SpotlightIndex(
        channel: const MethodChannel('readendar/spotlight'),
      );
      final book = Book(
        id: 'b1',
        ownerType: 'user',
        ownerId: 'u1',
        title: 'Dune',
        authors: const ['Herbert'],
        status: BookStatus.reading,
      );
      final n = await index.syncLibrary(
        books: [book],
        quotes: [Quote(id: 'q1', bookId: 'b1', text: 'Fear')],
      );
      if (index.isSupported) {
        expect(calls.map((c) => c.method), ['deleteAll', 'indexItems']);
        expect(n, 2);
      } else {
        expect(n, 0);
        expect(calls, isEmpty);
      }
    });
  });
}
