import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/notification_actions.dart';
import 'package:readendar/features/notifications/notification_store.dart';
import 'package:readendar/features/notifications/pending_action_drainer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/api_repo_stubs.dart';

AppUser _user(String id) => AppUser(
  id: id,
  email: '$id@x.io',
  displayName: id,
  preferredLocale: 'es',
  timezone: 'Europe/Madrid',
  onboardingCompletedAt: DateTime.utc(2026),
);

PendingAction _complete(String owner, String event, {int? ts}) => PendingAction(
  action: kActionComplete,
  ownerUserId: owner,
  eventId: event,
  ts: ts ?? DateTime.now().millisecondsSinceEpoch,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Captures a real WidgetRef from a mounted Consumer, with the prefs + event
  // repo overridden. Seeds [pending] into the queue before draining.
  Future<
    ({
      WidgetRef ref,
      _FakeEventRepository repo,
      SharedPreferences prefs,
      ValueNotifier<bool> showConsumer,
    })
  >
  harness(
    WidgetTester tester,
    List<PendingAction> pending, {
    DataPlane dataPlane = DataPlane.local,
  }) async {
    // Seed through the mock's initial values (keys are stored with the
    // `flutter.` prefix) so the drainer's `prefs.reload()` — which reverts the
    // cache to the mock backing store — still sees the queued actions.
    SharedPreferences.setMockInitialValues({
      if (pending.isNotEmpty)
        'flutter.readendar_pending_notif_actions': jsonEncode([
          for (final p in pending) p.toJson(),
        ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeEventRepository();
    final showConsumer = ValueNotifier(true);
    addTearDown(showConsumer.dispose);

    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          eventRepoProvider.overrideWithValue(repo),
          dataPlaneProvider.overrideWithValue(dataPlane),
        ],
        child: ValueListenableBuilder<bool>(
          valueListenable: showConsumer,
          builder: (context, visible, child) => visible
              ? Consumer(
                  builder: (context, ref, child) {
                    captured = ref;
                    return const SizedBox();
                  },
                )
              : const SizedBox(),
        ),
      ),
    );
    return (
      ref: captured,
      repo: repo,
      prefs: prefs,
      showConsumer: showConsumer,
    );
  }

  testWidgets('completes queued events for the user and empties the queue', (
    tester,
  ) async {
    final h = await harness(tester, [
      _complete('u1', 'e1'),
      _complete('u1', 'e2'),
    ]);
    h.repo.results['e1'] = Ok(_event('e1', bookId: 'b1'));
    h.repo.results['e2'] = Ok(_event('e2'));

    final count = await drainPendingCompletions(h.ref, _user('u1'));

    expect(count, 2);
    expect(h.repo.completed, ['e1', 'e2']);
    expect(PendingActionsStore.readAll(h.prefs), isEmpty);
  });

  testWidgets('terminal failure (conflict) is dropped, not retried', (
    tester,
  ) async {
    final h = await harness(tester, [_complete('u1', 'gone')]);
    h.repo.results['gone'] = const Err(ConflictFailure('already_completed'));

    final count = await drainPendingCompletions(h.ref, _user('u1'));

    expect(count, 0);
    expect(h.repo.completed, ['gone']); // attempted once
    expect(PendingActionsStore.readAll(h.prefs), isEmpty); // dropped
  });

  testWidgets('transient failure (network) is kept for a later retry', (
    tester,
  ) async {
    final h = await harness(tester, [_complete('u1', 'e1')]);
    h.repo.results['e1'] = const Err(NetworkFailure());

    final count = await drainPendingCompletions(h.ref, _user('u1'));

    expect(count, 0);
    expect(PendingActionsStore.readAll(h.prefs).single.eventId, 'e1');
  });

  testWidgets("another account's queued action is left untouched on API plane", (
    tester,
  ) async {
    final h = await harness(tester, [
      _complete('u1', 'mine'),
      _complete('u2', 'theirs'),
    ], dataPlane: DataPlane.api);
    h.repo.results['mine'] = Ok(_event('mine'));

    final count = await drainPendingCompletions(h.ref, _user('u1'));

    expect(count, 1);
    expect(h.repo.completed, ['mine']); // never touched u2's entry
    expect(PendingActionsStore.readAll(h.prefs).single.eventId, 'theirs');
  });

  testWidgets('a Complete enqueued during the drain is not clobbered', (
    tester,
  ) async {
    final h = await harness(tester, [_complete('u1', 'e1')]);
    h.repo.results['e1'] = Ok(_event('e1'));
    // Simulate the foreground handler / background isolate queueing another
    // Complete while `repo.complete('e1')` is in flight.
    h.repo.prefs = h.prefs;
    h.repo.injectOnFirstComplete = _complete('u1', 'concurrent');

    final count = await drainPendingCompletions(h.ref, _user('u1'));

    expect(count, 1);
    // e1 removed, but the concurrently-queued entry survives for the next drain.
    expect(
      PendingActionsStore.readAll(h.prefs).map((e) => e.eventId),
      ['concurrent'],
    );
  });

  testWidgets('local plane drains legacy cloud owner ids', (tester) async {
    final h = await harness(tester, [_complete('legacy-cloud-uuid', 'e1')]);
    h.repo.results['e1'] = Ok(_event('e1'));

    final count = await drainPendingCompletions(h.ref, _user(localGuestUserId));

    expect(count, 1);
    expect(h.repo.completed, ['e1']);
    expect(PendingActionsStore.readAll(h.prefs), isEmpty);
  });

  testWidgets('stale entries are dropped unattempted', (tester) async {
    final old = DateTime.now()
        .subtract(const Duration(days: 8))
        .millisecondsSinceEpoch;
    final h = await harness(tester, [_complete('u1', 'old', ts: old)]);

    final count = await drainPendingCompletions(h.ref, _user('u1'));

    expect(count, 0);
    expect(h.repo.completed, isEmpty); // never called
    expect(PendingActionsStore.readAll(h.prefs), isEmpty);
  });

  testWidgets('completion refresh survives the initiating widget unmounting', (
    tester,
  ) async {
    final h = await harness(tester, [_complete('u1', 'e1')]);
    h.repo.delayedResult = Completer<Result<ReadingEvent>>();

    final drain = drainPendingCompletions(h.ref, _user('u1'));
    await h.repo.completeStarted.future;
    h.showConsumer.value = false;
    await tester.pump();
    h.repo.delayedResult!.complete(Ok(_event('e1', bookId: 'b1')));

    expect(await drain, 1);
    expect(tester.takeException(), isNull);
  });
}

ReadingEvent _event(String id, {String? bookId}) => ReadingEvent(
  id: id,
  ownerType: 'user',
  ownerId: 'u1',
  bookId: bookId,
  type: 'chapter_milestone',
  title: 't',
  dateLocal: DateTime.utc(2026, 7),
  status: 'completed',
);

class _FakeEventRepository extends ApiEventRepository {
  _FakeEventRepository() : super(_fakeApi());

  final List<String> completed = [];
  final Map<String, Result<ReadingEvent>> results = {};
  final Completer<void> completeStarted = Completer<void>();
  Completer<Result<ReadingEvent>>? delayedResult;

  // To simulate a Complete enqueued (foreground handler / background isolate)
  // WHILE the drain is mid-loop: injected into the store on the first complete.
  SharedPreferences? prefs;
  PendingAction? injectOnFirstComplete;

  @override
  Future<Result<ReadingEvent>> complete(String id) async {
    completed.add(id);
    if (!completeStarted.isCompleted) completeStarted.complete();
    final inject = injectOnFirstComplete;
    if (inject != null && prefs != null) {
      injectOnFirstComplete = null;
      await PendingActionsStore.enqueue(prefs!, inject);
    }
    return delayedResult == null
        ? results[id] ?? const Err(UnknownFailure())
        : delayedResult!.future;
  }
}

ApiClient _fakeApi() => ApiClient(
  baseUrl: 'http://localhost',
  storage: _FakeSecureTokenStorage(),
  localeProvider: () => 'es',
);

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}
