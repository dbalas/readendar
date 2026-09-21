import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/notifications/notification_actions.dart';
import 'package:readendar/features/notifications/notification_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> freshPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  group('PendingActionsStore', () {
    test('enqueue → readAll preserves order and fields', () async {
      final prefs = await freshPrefs();
      await PendingActionsStore.enqueue(
        prefs,
        const PendingAction(
          action: kActionComplete,
          ownerUserId: 'u1',
          eventId: 'e1',
          ts: 100,
        ),
      );
      await PendingActionsStore.enqueue(
        prefs,
        const PendingAction(
          action: kActionComplete,
          ownerUserId: 'u2',
          eventId: 'e2',
          ts: 200,
        ),
      );
      final all = PendingActionsStore.readAll(prefs);
      expect(all.map((a) => a.eventId), ['e1', 'e2']);
      expect(all.first.ownerUserId, 'u1');
      expect(all.last.ts, 200);
    });

    test('writeAll replaces the queue; empty removes the key', () async {
      final prefs = await freshPrefs();
      await PendingActionsStore.enqueue(
        prefs,
        const PendingAction(
          action: kActionComplete,
          ownerUserId: 'u1',
          eventId: 'e1',
          ts: 1,
        ),
      );
      await PendingActionsStore.writeAll(prefs, const [
        PendingAction(
          action: kActionComplete,
          ownerUserId: 'u9',
          eventId: 'e9',
          ts: 9,
        ),
      ]);
      expect(PendingActionsStore.readAll(prefs).single.eventId, 'e9');
      await PendingActionsStore.writeAll(prefs, const []);
      expect(PendingActionsStore.readAll(prefs), isEmpty);
    });

    test('readAll tolerates absent / corrupt data', () async {
      final prefs = await freshPrefs();
      expect(PendingActionsStore.readAll(prefs), isEmpty);
    });

    test('migrates the legacy array without losing a new action', () async {
      SharedPreferences.setMockInitialValues({
        'readendar_pending_notif_actions':
            '[{"a":"complete","o":"u1","e":"legacy","ts":1}]',
      });
      final prefs = await SharedPreferences.getInstance();
      await PendingActionsStore.enqueue(
        prefs,
        const PendingAction(
          action: kActionComplete,
          ownerUserId: 'u1',
          eventId: 'new',
          ts: 2,
        ),
      );

      expect(
        PendingActionsStore.readAll(prefs).map((action) => action.eventId),
        ['legacy', 'new'],
      );
    });

    test('removing one action leaves independently enqueued actions intact',
        () async {
      final prefs = await freshPrefs();
      const first = PendingAction(
        action: kActionComplete,
        ownerUserId: 'u1',
        eventId: 'first',
        ts: 1,
      );
      const second = PendingAction(
        action: kActionComplete,
        ownerUserId: 'u1',
        eventId: 'second',
        ts: 2,
      );
      await PendingActionsStore.enqueue(prefs, first);
      await PendingActionsStore.enqueue(prefs, second);
      await PendingActionsStore.remove(prefs, [first]);

      expect(PendingActionsStore.readAll(prefs), [second]);
    });
  });

  group('NotifMetaStore', () {
    NotifMeta meta(String owner) => NotifMeta(
      title: 'Reach chapter 5',
      body: 'Dune',
      channelName: 'Recordatorios',
      channelDescription: 'desc',
      ownerUserId: owner,
      eventId: 'e1',
      categoryId: NotifCategory.milestonePlan.id,
      androidActions: const [
        NotifAction(id: kActionComplete, title: 'Completar', foreground: false),
        NotifAction(id: kActionSnooze1h, title: 'Posponer 1 h', foreground: false),
      ],
      payload: 'owner:$owner|event:e1',
      tz: 'Europe/Madrid',
    );

    test('write → read round-trips content and actions', () async {
      final prefs = await freshPrefs();
      await NotifMetaStore.write(prefs, 42, meta('u1'));
      final read = NotifMetaStore.read(prefs, 42)!;
      expect(read.title, 'Reach chapter 5');
      expect(read.body, 'Dune');
      expect(read.categoryId, NotifCategory.milestonePlan.id);
      expect(read.tz, 'Europe/Madrid');
      expect(read.androidActions.map((a) => a.id), [
        kActionComplete,
        kActionSnooze1h,
      ]);
      expect(read.androidActions.last.foreground, isFalse);
    });

    test('remove deletes only the given id', () async {
      final prefs = await freshPrefs();
      await NotifMetaStore.write(prefs, 1, meta('u1'));
      await NotifMetaStore.write(prefs, 2, meta('u1'));
      await NotifMetaStore.remove(prefs, 1);
      expect(NotifMetaStore.read(prefs, 1), isNull);
      expect(NotifMetaStore.read(prefs, 2), isNotNull);
    });

    test("removeForOwner drops only that owner's entries", () async {
      final prefs = await freshPrefs();
      await NotifMetaStore.write(prefs, 1, meta('u1'));
      await NotifMetaStore.write(prefs, 2, meta('u2'));
      await NotifMetaStore.removeForOwner(prefs, 'u1');
      expect(NotifMetaStore.read(prefs, 1), isNull);
      expect(NotifMetaStore.read(prefs, 2), isNotNull);
    });

    test('read returns null for a missing id', () async {
      final prefs = await freshPrefs();
      expect(NotifMetaStore.read(prefs, 999), isNull);
    });

    test(
      'runBatched coalesces writes and reads see the buffer mid-batch',
      () async {
        final prefs = await freshPrefs();
        await NotifMetaStore.runBatched(prefs, () async {
          await NotifMetaStore.write(prefs, 1, meta('u1'));
          await NotifMetaStore.write(prefs, 2, meta('u1'));
          // A mid-batch read sees the in-memory buffer, not the (empty) store.
          expect(NotifMetaStore.read(prefs, 1), isNotNull);
          await NotifMetaStore.remove(prefs, 1);
          expect(NotifMetaStore.read(prefs, 1), isNull);
        });
        // After the single flush only id 2 survives.
        expect(NotifMetaStore.read(prefs, 1), isNull);
        expect(NotifMetaStore.read(prefs, 2), isNotNull);
      },
    );

    test('removeForOwner inside a batch is honored at flush', () async {
      final prefs = await freshPrefs();
      await NotifMetaStore.write(prefs, 1, meta('u1'));
      await NotifMetaStore.runBatched(prefs, () async {
        await NotifMetaStore.write(prefs, 2, meta('u2'));
        await NotifMetaStore.removeForOwner(prefs, 'u1');
      });
      expect(NotifMetaStore.read(prefs, 1), isNull);
      expect(NotifMetaStore.read(prefs, 2), isNotNull);
    });

    test(
      'concurrent direct write waits for and merges after a batch',
      () async {
        final prefs = await freshPrefs();
        final batchStarted = Completer<void>();
        final releaseBatch = Completer<void>();
        var directCompleted = false;

        final batch = NotifMetaStore.runBatched(prefs, () async {
          await NotifMetaStore.write(prefs, 1, meta('u1'));
          batchStarted.complete();
          await releaseBatch.future;
        });
        await batchStarted.future;

        final direct = NotifMetaStore.write(prefs, 2, meta('u2')).then((_) {
          directCompleted = true;
        });
        await Future<void>.delayed(Duration.zero);
        expect(directCompleted, isFalse);

        releaseBatch.complete();
        await Future.wait([batch, direct]);
        expect(NotifMetaStore.read(prefs, 1), isNotNull);
        expect(NotifMetaStore.read(prefs, 2), isNotNull);
      },
    );

    test(
      'failed batch still persists metadata for schedules already armed',
      () async {
        final prefs = await freshPrefs();

        await expectLater(
          NotifMetaStore.runBatched<void>(prefs, () async {
            await NotifMetaStore.write(prefs, 7, meta('u1'));
            throw StateError('later platform schedule failed');
          }),
          throwsStateError,
        );

        expect(NotifMetaStore.read(prefs, 7), isNotNull);
      },
    );

    test(
      'entriesForOwner returns only parseable entries for that owner',
      () async {
        final prefs = await freshPrefs();
        await NotifMetaStore.write(prefs, 1, meta('u1'));
        await NotifMetaStore.write(prefs, 2, meta('u2'));

        expect(NotifMetaStore.entriesForOwner(prefs, 'u1').keys, {1});
      },
    );
  });
}
