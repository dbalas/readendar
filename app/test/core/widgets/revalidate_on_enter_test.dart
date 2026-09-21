import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/widgets/revalidate_on_enter.dart';

void main() {
  setUp(resetRevalidationThrottle);

  testWidgets('first mount does not duplicate the initial fetch', (
    tester,
  ) async {
    var fetches = 0;
    final counter = FutureProvider<int>((ref) async {
      fetches += 1;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return 1;
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RevalidateOnEnter(
            providers: [counter],
            child: Consumer(
              builder: (context, ref, _) => Text(
                '${ref.watch(counter).value}',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(fetches, 1);
  });

  testWidgets(
    're-entry shows cached data immediately and revalidates in the background',
    (tester) async {
      var backendValue = 1;
      var fetches = 0;
      final counter = FutureProvider<int>((ref) async {
        fetches += 1;
        return backendValue;
      });

      var entryKey = 0;
      late StateSetter setOuter;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return RevalidateOnEnter(
                  key: ValueKey(entryKey),
                  staleAfter: Duration.zero,
                  providers: [counter],
                  child: Consumer(
                    builder: (context, ref, _) {
                      final v = ref.watch(counter);
                      final label = v.isLoading && !v.hasValue
                          ? 'loading'
                          : 'v=${v.value}';
                      return Text(label, textDirection: TextDirection.ltr);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // First load resolves to the initial backend value.
      await tester.pumpAndSettle();
      expect(find.text('v=1'), findsOneWidget);

      // Backend changes while we're away.
      backendValue = 2;
      final fetchesBeforeReentry = fetches;

      // Re-enter the view (remount under a new key, same ProviderScope so the
      // cache persists).
      setOuter(() => entryKey = 1);
      await tester.pump(); // mount
      await tester.pump(); // run the post-frame revalidation callback

      // The cached value is still on screen — no loading spinner — even though a
      // background refetch is now in flight.
      expect(find.text('loading'), findsNothing);
      expect(find.text('v=1'), findsOneWidget);
      expect(fetches, greaterThan(fetchesBeforeReentry));

      // Once the refetch completes, the new value appears silently.
      await tester.pumpAndSettle();
      expect(find.text('v=2'), findsOneWidget);
    },
  );

  testWidgets('throttles revalidation within the stale window', (tester) async {
    var fetches = 0;
    final counter = FutureProvider<int>((ref) async {
      fetches += 1;
      return 0;
    });

    var entryKey = 0;
    late StateSetter setOuter;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return RevalidateOnEnter(
                key: ValueKey(entryKey),
                // Long window: a quick re-entry must NOT hit the backend again.
                staleAfter: const Duration(minutes: 5),
                providers: [counter],
                child: Consumer(
                  builder: (context, ref, _) => Text(
                    '${ref.watch(counter).value}',
                    textDirection: TextDirection.ltr,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final afterFirstMount = fetches;

    setOuter(() => entryKey = 1);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      fetches,
      afterFirstMount,
      reason: 'within the stale window the re-entry must not refetch',
    );
  });
}
