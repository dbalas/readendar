import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_actions.dart';
import 'package:readendar/features/notifications/notification_tap_handler.dart';
import 'package:readendar/features/quotes/book_annotations_screen.dart';
import 'package:readendar/features/widget/widget_deep_link.dart';

import '../quotes/quotes_test_utils.dart';

void main() {
  testWidgets('notification tap received during overlay build is deferred', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    var callbackDelivered = false;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NotificationTapHandler(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  Overlay.of(context).insert(
                    OverlayEntry(
                      builder: (_) {
                        if (!callbackDelivered) {
                          callbackDelivered = true;
                          LocalNotifications.I.onEventTap?.call(
                            'event-1',
                            NotifIntent.open,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  );
                },
                child: const Text('Open overlay'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open overlay'));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      container.read(pendingNotificationTapProvider),
      (eventId: 'event-1', intent: NotifIntent.open),
    );
  });

  testWidgets('quote-of-the-day tap opens BookAnnotationsScreen', (tester) async {
    final quote = testQuote(id: 'quote-42');
    final container = ProviderContainer(
      overrides: [
        quoteRepoProvider.overrideWithValue(FakeQuoteRepository([quote])),
        booksProvider.overrideWith((ref) async => [testBook()]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const NotificationTapHandler(
            child: Scaffold(body: Text('shell')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(LocalNotifications.I.onQuoteTap, isNotNull);

    LocalNotifications.I.onQuoteTap!('quote-42');
    await tester.pump(); // post-frame open
    await tester.pumpAndSettle(); // complete the pushed route's shared fade

    expect(find.byType(BookAnnotationsScreen), findsOneWidget);
    final screen = tester.widget<BookAnnotationsScreen>(
      find.byType(BookAnnotationsScreen),
    );
    expect(screen.bookId, 'b1');
    expect(screen.highlightAnnotationId, 'quote-42');
  });

  testWidgets(
    'quote tap falls back to pending widget deep link when navigator missing',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Build the handler WITHOUT a MaterialApp ancestor so Navigator.maybeOf
      // returns null and the fallback deep-link stash runs.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: NotificationTapHandler(child: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();

      LocalNotifications.I.onQuoteTap!('quote-fallback');
      await tester.pump();
      await tester.pump();

      expect(
        container.read(pendingWidgetDeepLinkProvider),
        const WidgetDeepLink(WidgetLinkKind.quote, 'quote-fallback'),
      );
    },
  );
}
