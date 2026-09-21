import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:readendar/features/widget/widget_deep_link.dart';
import 'package:readendar/features/widget/widget_models.dart';

void main() {
  group('WidgetDeepLinkListener.start', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    const homeWidgetChannel = MethodChannel('home_widget');
    const appLinksChannel = MethodChannel('com.llfbandit.app_links/messages');
    const homeWidgetEvents = EventChannel('home_widget/updates');
    const appLinksEvents = EventChannel('com.llfbandit.app_links/events');

    test('registers App Group before cold-start widget launch check', () async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(appLinksChannel, (call) async {
          if (call.method == 'getInitialLink') return null;
          return null;
        })
        ..setMockMethodCallHandler(homeWidgetChannel, (call) async {
          methods.add(call.method);
          switch (call.method) {
            case 'setAppGroupId':
              expect(call.arguments, {'groupId': kWidgetAppGroupId});
              return true;
            case 'initiallyLaunchedFromHomeWidget':
              // Without setAppGroupId first, iOS throws PlatformException(-7).
              expect(methods, contains('setAppGroupId'));
              return null;
            default:
              return null;
          }
        })
        ..setMockStreamHandler(
          homeWidgetEvents,
          MockStreamHandler.inline(
            onListen: (args, events) {},
          ),
        )
        ..setMockStreamHandler(
          appLinksEvents,
          MockStreamHandler.inline(
            onListen: (args, events) {},
          ),
        );

      final container = ProviderContainer();
      addTearDown(() {
        container.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(appLinksChannel, null)
          ..setMockMethodCallHandler(homeWidgetChannel, null)
          ..setMockStreamHandler(homeWidgetEvents, null)
          ..setMockStreamHandler(appLinksEvents, null);
      });

      await container.read(widgetDeepLinkProvider).startPlatformExtras();
      await container.read(widgetDeepLinkProvider).stop();

      expect(methods.first, 'setAppGroupId');
      expect(methods, contains('initiallyLaunchedFromHomeWidget'));
      expect(
        methods.indexOf('setAppGroupId'),
        lessThan(methods.indexOf('initiallyLaunchedFromHomeWidget')),
      );
    });

    test(
      'stashes a cold-start widget deep link after App Group is set',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(appLinksChannel, (call) async {
            if (call.method == 'getInitialLink') return null;
            return null;
          })
          ..setMockMethodCallHandler(homeWidgetChannel, (call) async {
            switch (call.method) {
              case 'setAppGroupId':
                return true;
              case 'initiallyLaunchedFromHomeWidget':
                return 'readendar://book/cold-start-book';
              default:
                return null;
            }
          })
          ..setMockStreamHandler(
            homeWidgetEvents,
            MockStreamHandler.inline(
              onListen: (args, events) {},
            ),
          )
          ..setMockStreamHandler(
            appLinksEvents,
            MockStreamHandler.inline(
              onListen: (args, events) {},
            ),
          );

        final container = ProviderContainer();
        addTearDown(() {
          container.dispose();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(appLinksChannel, null)
            ..setMockMethodCallHandler(homeWidgetChannel, null)
            ..setMockStreamHandler(homeWidgetEvents, null)
            ..setMockStreamHandler(appLinksEvents, null);
        });

        await container.read(widgetDeepLinkProvider).startPlatformExtras();
        expect(
          container.read(pendingWidgetDeepLinkProvider),
          const WidgetDeepLink(WidgetLinkKind.book, 'cold-start-book'),
        );
        await container.read(widgetDeepLinkProvider).stop();
      },
    );

    test(
      'drainPendingShareIfAny stages shareQuote when App Group has text',
      () async {
        String? stored;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(appLinksChannel, (call) async {
            if (call.method == 'getInitialLink') return null;
            return null;
          })
          ..setMockMethodCallHandler(homeWidgetChannel, (call) async {
            switch (call.method) {
              case 'setAppGroupId':
                return true;
              case 'getWidgetData':
                final id = (call.arguments as Map)['id'] as String?;
                if (id == kSharePendingQuoteTextKey) return stored;
                return null;
              case 'saveWidgetData':
                final args = Map<String, dynamic>.from(call.arguments as Map);
                if (args['id'] == kSharePendingQuoteTextKey) {
                  stored = args['data'] as String?;
                }
                return true;
              case 'initiallyLaunchedFromHomeWidget':
                return null;
              default:
                return null;
            }
          })
          ..setMockStreamHandler(
            homeWidgetEvents,
            MockStreamHandler.inline(onListen: (args, events) {}),
          )
          ..setMockStreamHandler(
            appLinksEvents,
            MockStreamHandler.inline(onListen: (args, events) {}),
          );

        final container = ProviderContainer();
        addTearDown(() {
          container.dispose();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(appLinksChannel, null)
            ..setMockMethodCallHandler(homeWidgetChannel, null)
            ..setMockStreamHandler(homeWidgetEvents, null)
            ..setMockStreamHandler(appLinksEvents, null);
        });

        await container.read(widgetDeepLinkProvider).startPlatformExtras();
        stored = 'Fear is the mind-killer.';
        await container.read(widgetDeepLinkProvider).drainPendingShareIfAny();
        expect(
          container.read(pendingWidgetDeepLinkProvider),
          const WidgetDeepLink(WidgetLinkKind.shareQuote, ''),
        );
        // Re-staged for the handler's single take.
        expect(stored, 'Fear is the mind-killer.');
        await container.read(widgetDeepLinkProvider).stop();
      },
    );

    test('drain does not overwrite a live share URI pending link', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(appLinksChannel, (call) async {
          if (call.method == 'getInitialLink') return null;
          return null;
        })
        ..setMockMethodCallHandler(homeWidgetChannel, (call) async {
          switch (call.method) {
            case 'setAppGroupId':
              return true;
            case 'getWidgetData':
              return 'should-not-drain';
            case 'initiallyLaunchedFromHomeWidget':
              return null;
            default:
              return null;
          }
        })
        ..setMockStreamHandler(
          homeWidgetEvents,
          MockStreamHandler.inline(onListen: (args, events) {}),
        )
        ..setMockStreamHandler(
          appLinksEvents,
          MockStreamHandler.inline(onListen: (args, events) {}),
        );

      final container = ProviderContainer();
      addTearDown(() {
        container.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(appLinksChannel, null)
          ..setMockMethodCallHandler(homeWidgetChannel, null)
          ..setMockStreamHandler(homeWidgetEvents, null)
          ..setMockStreamHandler(appLinksEvents, null);
      });

      container.read(pendingWidgetDeepLinkProvider.notifier).state =
          const WidgetDeepLink(WidgetLinkKind.shareQuote, '');
      await container.read(widgetDeepLinkProvider).drainPendingShareIfAny();
      expect(
        container.read(pendingWidgetDeepLinkProvider),
        const WidgetDeepLink(WidgetLinkKind.shareQuote, ''),
      );
      await container.read(widgetDeepLinkProvider).stop();
    });
  });

  group('parseWidgetDeepLink', () {
    test('parses the quotes-config link with appWidgetId + config', () {
      final link = parseWidgetDeepLink(
        Uri.parse(
          'readendar://widget-quotes-config?wid=7&mode=fixed&quoteId=q1&cadence=6h',
        ),
      );
      expect(link!.kind, WidgetLinkKind.quotesConfig);
      expect(link.widgetId, 7);
      expect(link.config!.mode, QuotesWidgetMode.fixed);
      expect(link.config!.quoteId, 'q1');
      expect(link.config!.cadence, QuotesWidgetCadence.sixHourly);
    });

    test('quotes-config link tolerates a missing wid (iOS) + blank ids', () {
      final link = parseWidgetDeepLink(
        Uri.parse('readendar://widget-quotes-config?mode=all&cadence=daily'),
      );
      expect(link!.kind, WidgetLinkKind.quotesConfig);
      expect(link.widgetId, isNull);
      expect(link.config!.mode, QuotesWidgetMode.all);
      expect(link.config!.bookId, isNull);
      expect(link.config!.quoteId, isNull);
    });

    test('parses book + event links', () {
      expect(
        parseWidgetDeepLink(Uri.parse('readendar://book/abc-123')),
        const WidgetDeepLink(WidgetLinkKind.book, 'abc-123'),
      );
      expect(
        parseWidgetDeepLink(Uri.parse('readendar://event/ev-9')),
        const WidgetDeepLink(WidgetLinkKind.event, 'ev-9'),
      );
    });

    test('parses progress editor and library links', () {
      expect(
        parseWidgetDeepLink(Uri.parse('readendar://progress/book-7')),
        const WidgetDeepLink(WidgetLinkKind.progress, 'book-7'),
      );
      expect(
        parseWidgetDeepLink(Uri.parse('readendar://progress')),
        const WidgetDeepLink(WidgetLinkKind.progress, ''),
      );
      expect(
        parseWidgetDeepLink(Uri.parse('readendar://library')),
        const WidgetDeepLink(WidgetLinkKind.library, ''),
      );
    });

    test('parses the id-less calendar link (see-more footer)', () {
      expect(
        parseWidgetDeepLink(Uri.parse('readendar://calendar')),
        const WidgetDeepLink(WidgetLinkKind.calendar, ''),
      );
    });

    test(
      'parses quote links: id opens the quote, "new" opens the composer',
      () {
        expect(
          parseWidgetDeepLink(Uri.parse('readendar://quote/q-42')),
          const WidgetDeepLink(WidgetLinkKind.quote, 'q-42'),
        );
        expect(
          parseWidgetDeepLink(Uri.parse('readendar://annotation/q-42')),
          const WidgetDeepLink(WidgetLinkKind.quote, 'q-42'),
        );
        expect(
          parseWidgetDeepLink(Uri.parse('readendar://quote/new')),
          const WidgetDeepLink(WidgetLinkKind.quoteNew, ''),
        );
      },
    );

    test('parses share-quote ingest handoff', () {
      expect(
        parseWidgetDeepLink(Uri.parse('readendar://share/quote')),
        const WidgetDeepLink(WidgetLinkKind.shareQuote, ''),
      );
      expect(parseWidgetDeepLink(Uri.parse('readendar://share')), isNull);
      expect(parseWidgetDeepLink(Uri.parse('readendar://share/other')), isNull);
      expect(parseWidgetDeepLink(Uri.parse('readendar://share/scan')), isNull);
    });

    test('rejects wrong scheme, unknown host, or missing id', () {
      expect(parseWidgetDeepLink(Uri.parse('https://book/x')), isNull);
      expect(parseWidgetDeepLink(Uri.parse('readendar://unknown/x')), isNull);
      expect(parseWidgetDeepLink(Uri.parse('readendar://book')), isNull);
      expect(parseWidgetDeepLink(Uri.parse('readendar://book/')), isNull);
      expect(parseWidgetDeepLink(Uri.parse('readendar://quote')), isNull);
      expect(parseWidgetDeepLink(Uri.parse('readendar://quote/')), isNull);
    });
  });
}
