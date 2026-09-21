import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_content.dart';
import 'package:readendar/features/notifications/notification_payload.dart';
import 'package:readendar/features/notifications/notification_resync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/api_repo_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('readFreshProviderFuture', () {
    ProviderContainer containerWithFailFast() => ProviderContainer(
      // Match production ProviderScope: no Riverpod auto-retry.
      retry: (_, _) => null,
    );

    test('refetches after a cached timeout instead of rethrowing it', () async {
      var calls = 0;
      final provider = FutureProvider<int>((ref) async {
        calls++;
        if (calls == 1) {
          throw const FailureException(
            NetworkFailure(
              'The request connection took longer than 0:00:10.000000',
            ),
          );
        }
        return 7;
      });
      final container = containerWithFailFast();
      addTearDown(container.dispose);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);

      await expectLater(
        container.read(provider.future),
        throwsA(isA<FailureException>()),
      );
      expect(calls, 1);
      expect(container.read(provider).hasError, isTrue);

      await expectLater(
        container.read(provider.future),
        throwsA(isA<FailureException>()),
      );
      expect(calls, 1, reason: 'cached error must not refetch by itself');

      expect(await readFreshProviderFuture(container, provider), 7);
      expect(calls, 2);
      expect(container.read(provider).hasError, isFalse);
    });

    test('reuses a successful cache', () async {
      var calls = 0;
      final provider = FutureProvider<int>((ref) async {
        calls++;
        return 3;
      });
      final container = containerWithFailFast();
      addTearDown(container.dispose);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);

      expect(await readFreshProviderFuture(container, provider), 3);
      expect(await readFreshProviderFuture(container, provider), 3);
      expect(calls, 1);
    });
  });

  group('notificationSyncRetryDelay', () {
    test('backs off from 3s to a 60s cap', () {
      expect(notificationSyncRetryDelay(0), Duration.zero);
      expect(notificationSyncRetryDelay(1), const Duration(seconds: 3));
      expect(notificationSyncRetryDelay(2), const Duration(seconds: 6));
      expect(notificationSyncRetryDelay(3), const Duration(seconds: 12));
      expect(notificationSyncRetryDelay(4), const Duration(seconds: 24));
      expect(notificationSyncRetryDelay(5), const Duration(seconds: 48));
      expect(notificationSyncRetryDelay(6), const Duration(seconds: 60));
      expect(notificationSyncRetryDelay(20), const Duration(seconds: 60));
    });
  });

  group('shouldRetryNotificationSync', () {
    test('retries transient network and server failures', () {
      expect(
        shouldRetryNotificationSync(
          const FailureException(NetworkFailure('timeout')),
        ),
        isTrue,
      );
      expect(
        shouldRetryNotificationSync(
          const FailureException(ServerFailure('unavailable')),
        ),
        isTrue,
      );
      expect(
        shouldRetryNotificationSync(
          const FailureException(RateLimitedFailure(30)),
        ),
        isTrue,
      );
    });

    test('does not retry authz or validation failures', () {
      expect(
        shouldRetryNotificationSync(
          const FailureException(UnauthorizedFailure()),
        ),
        isFalse,
      );
      expect(
        shouldRetryNotificationSync(
          const FailureException(ForbiddenFailure()),
        ),
        isFalse,
      );
      expect(
        shouldRetryNotificationSync(
          const FailureException(ValidationFailure('invalid')),
        ),
        isFalse,
      );
    });

    test('summarizes FailureException as the failure code', () {
      expect(
        notificationSyncFailureSummary(
          const FailureException(
            NetworkFailure(
              'The request connection took longer than 0:00:10.000000',
            ),
          ),
        ),
        'network',
      );
    });
  });

  group('loadNotificationPreferencesForResync', () {
    NotificationPreferences prefs() => NotificationPreferences(
      globalEnabled: true,
      defaultReminderMinutesBefore: 30,
      allDayReminderHour: 9,
    );

    test('uses a warm provider cache without a second fetch', () async {
      var repoCalls = 0;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          notificationPrefsProvider.overrideWith((ref) async => prefs()),
          notificationRepoProvider.overrideWithValue(
            _FakeNotificationRepo(() {
              repoCalls++;
              return Err(const NetworkFailure('timeout'));
            }),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(notificationPrefsProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(notificationPrefsProvider.future);

      final loaded = await loadNotificationPreferencesForResync(container);
      expect(loaded.globalEnabled, isTrue);
      expect(repoCalls, 0);
    });

    test('fetches via the repo without creating a provider error', () async {
      var repoCalls = 0;
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          notificationRepoProvider.overrideWithValue(
            _FakeNotificationRepo(() {
              repoCalls++;
              return Err(const NetworkFailure('timeout'));
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        loadNotificationPreferencesForResync(container),
        throwsA(
          isA<FailureException>().having(
            (e) => e.failure,
            'failure',
            isA<NetworkFailure>(),
          ),
        ),
      );
      expect(repoCalls, 1);
      expect(container.exists(notificationPrefsProvider), isFalse);
    });
  });

  late AppL10n l;
  late AppUser user;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    l = lookupAppL10n(const Locale('es'));
    user = AppUser(
      id: 'user-1',
      email: 'reader@example.com',
      displayName: 'Reader',
      preferredLocale: 'es',
      timezone: 'Europe/Madrid',
      onboardingCompletedAt: DateTime.utc(2026),
    );
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  Future<void> reconcile(
    _FakeScheduler scheduler, {
    List<ReadingEvent>? events,
    Future<List<Book>> Function()? loadBooks,
    bool globalEnabled = true,
    Future<bool> Function()? requestNotificationPermission,
    bool Function()? shouldContinue,
  }) async {
    await reconcileEventReminders(
      l: l,
      user: user,
      scheduler: scheduler,
      sharedPreferences: await prefs(),
      loadPreferences: () async => NotificationPreferences(
        globalEnabled: globalEnabled,
        defaultReminderMinutesBefore: 30,
        allDayReminderHour: 9,
      ),
      loadEvents: () async => events ?? [_event('event-1')],
      loadBooks: loadBooks ?? () async => const <Book>[],
      requestNotificationPermission: requestNotificationPermission,
      shouldContinue: shouldContinue,
    );
  }

  test('dependency failure preserves the previously armed schedule', () async {
    final scheduler = _FakeScheduler();

    await expectLater(
      reconcile(
        scheduler,
        loadBooks: () async => throw StateError('books unavailable'),
      ),
      throwsStateError,
    );

    expect(scheduler.actions, isEmpty);
  });

  test('schedule failure does not run stale-reminder cleanup', () async {
    final scheduler = _FakeScheduler(throwOnEventId: 'event-2');

    await expectLater(
      reconcile(
        scheduler,
        events: [_event('event-1'), _event('event-2')],
      ),
      throwsStateError,
    );

    expect(scheduler.actions, [
      'schedule:event-1',
      'schedule:event-2',
      'rollback:2',
    ]);
    expect(scheduler.rolledBackIds, {
      eventNotificationId(user.id, 'event-1'),
      eventNotificationId(user.id, 'event-2'),
    });
  });

  test(
    'partial failure keeps a stable alarm that existed before the attempt',
    () async {
      final existingId = eventNotificationId(user.id, 'event-1');
      final scheduler = _FakeScheduler(
        throwOnEventId: 'event-2',
        preexistingIds: {existingId},
      );

      await expectLater(
        reconcile(
          scheduler,
          events: [_event('event-1'), _event('event-2')],
        ),
        throwsStateError,
      );

      expect(scheduler.rolledBackIds, {
        eventNotificationId(user.id, 'event-2'),
      });
    },
  );

  test(
    'stale reminders are removed only after every desired schedule',
    () async {
      final scheduler = _FakeScheduler(notArmedEventId: 'event-2');

      await reconcile(
        scheduler,
        events: [_event('event-1'), _event('event-2')],
      );

      expect(scheduler.actions, [
        'schedule:event-1',
        'schedule:event-2',
        'cleanup:event-1',
      ]);
      expect(scheduler.lastRetainedEventIds, {'event-1', 'event-2'});
    },
  );

  test('disabled global notifications take the cancel-only shortcut', () async {
    final scheduler = _FakeScheduler();

    await reconcile(scheduler, globalEnabled: false);

    expect(scheduler.actions, ['cancel-all']);
  });

  test(
    'permission is requested after reminder preflight and before scheduling',
    () async {
      final trace = <String>[];
      final scheduler = _FakeScheduler(trace: trace);

      await reconcile(
        scheduler,
        requestNotificationPermission: () async {
          trace.add('permission');
          return true;
        },
      );

      expect(trace, [
        'preflight:event-1',
        'permission',
        'schedule:event-1',
        'cleanup:event-1',
      ]);
    },
  );

  test('permission denial preserves the previously armed schedule', () async {
    final trace = <String>[];
    final scheduler = _FakeScheduler(trace: trace);

    await reconcile(
      scheduler,
      requestNotificationPermission: () async {
        trace.add('permission');
        return false;
      },
    );

    expect(trace, ['preflight:event-1', 'permission']);
    expect(scheduler.actions, isEmpty);
  });

  test('notifications off does not request permission', () async {
    var permissionRequests = 0;
    final scheduler = _FakeScheduler();

    await reconcile(
      scheduler,
      globalEnabled: false,
      requestNotificationPermission: () async {
        permissionRequests++;
        return true;
      },
    );

    expect(permissionRequests, 0);
    expect(scheduler.actions, ['cancel-all']);
  });

  test(
    'event without an enabled reminder does not request permission',
    () async {
      var permissionRequests = 0;
      final scheduler = _FakeScheduler();

      await reconcile(
        scheduler,
        events: [_event('event-1', reminderEnabled: false)],
        requestNotificationPermission: () async {
          permissionRequests++;
          return true;
        },
      );

      expect(permissionRequests, 0);
      expect(scheduler.actions, ['cancel-all']);
    },
  );

  test(
    'past but still-live event prunes pending alarms without cancelling tray',
    () async {
      final scheduler = _FakeScheduler(notSchedulableEventId: 'event-1');

      await reconcile(scheduler);

      expect(scheduler.actions, ['cleanup:']);
      expect(scheduler.lastRetainedEventIds, {'event-1'});
    },
  );

  test('account switch rolls back ids introduced by the attempt', () async {
    var current = true;
    final scheduler = _FakeScheduler(onScheduled: (_) => current = false);

    await expectLater(
      reconcile(scheduler, shouldContinue: () => current),
      throwsA(isA<Exception>()),
    );

    expect(scheduler.rolledBackIds, {
      eventNotificationId(user.id, 'event-1'),
    });
  });

  test(
    'failure-safe window helper preserves pre-existing stable ids',
    () async {
      Set<int>? rolledBack;

      await expectLater(
        scheduleNotificationsFailureSafely<int>(
          items: const [11, 22, 33],
          preexistingIds: const {11},
          notificationIdFor: (id) => id,
          schedule: (id) async {
            if (id == 33) throw StateError('third quote failed');
            return id;
          },
          rollbackIntroduced: (ids) async => rolledBack = {...ids},
        ),
        throwsStateError,
      );

      expect(rolledBack, {22, 33});
    },
  );

  test(
    'failure-safe window does not roll back a known unscheduled id',
    () async {
      Set<int>? rolledBack;

      await expectLater(
        scheduleNotificationsFailureSafely<int>(
          items: const [11, 22],
          preexistingIds: const {},
          notificationIdFor: (id) => id,
          schedule: (id) async {
            if (id == 11) return null;
            throw StateError('later schedule failed');
          },
          rollbackIntroduced: (ids) async => rolledBack = {...ids},
        ),
        throwsStateError,
      );

      expect(rolledBack, {22});
    },
  );
}

ReadingEvent _event(
  String id, {
  bool reminderEnabled = true,
}) => ReadingEvent(
  id: id,
  ownerType: OwnerType.user,
  ownerId: 'user-1',
  type: 'deadline',
  title: 'Fecha límite',
  dateLocal: DateTime.utc(2026, 8, 2),
  timeLocal: '18:00',
  tz: 'Europe/Madrid',
  status: EventStatus.active,
  reminderEnabled: reminderEnabled,
  reminderMinutesBefore: 30,
);

class _FakeScheduler implements EventReminderScheduler {
  _FakeScheduler({
    this.throwOnEventId,
    this.notArmedEventId,
    this.notSchedulableEventId,
    this.preexistingIds = const {},
    this.onScheduled,
    this.trace,
  });

  final String? throwOnEventId;
  final String? notArmedEventId;
  final String? notSchedulableEventId;
  final Set<int> preexistingIds;
  final void Function(String eventId)? onScheduled;
  final List<String>? trace;
  final List<String> actions = [];
  Set<String>? lastRetainedEventIds;
  Set<int>? rolledBackIds;

  @override
  int notificationIdForEvent(String ownerUserId, String eventId) =>
      eventNotificationId(ownerUserId, eventId);

  @override
  bool canScheduleEventReminder(
    ReadingEvent event, {
    int allDayReminderHour = 9,
    String? viewerTz,
  }) {
    trace?.add('preflight:${event.id}');
    return event.id != notSchedulableEventId &&
        event.reminderEnabled &&
        event.reminderMinutesBefore != null;
  }

  @override
  Future<void> cancelEventRemindersForUser(String userId) async {
    actions.add('cancel-all');
    trace?.add('cancel-all');
  }

  @override
  Future<void> cancelEventNotificationIds(
    String userId,
    Set<int> notificationIds,
  ) async {
    rolledBackIds = {...notificationIds};
    actions.add('rollback:${notificationIds.length}');
  }

  @override
  Future<void> cancelStaleEventRemindersForUser(
    String userId,
    Map<String, int> expectedIdsByEventId,
    Set<String> retainedEventIds,
  ) async {
    lastRetainedEventIds = retainedEventIds;
    final action =
        'cleanup:${(expectedIdsByEventId.keys.toList()..sort()).join(',')}';
    actions.add(action);
    trace?.add(action);
  }

  @override
  Future<Set<int>> pendingEventNotificationIdsForUser(String userId) async =>
      preexistingIds;

  @override
  Future<int?> scheduleForEvent(
    ReadingEvent event, {
    required String ownerUserId,
    required String notificationChannelName,
    required String notificationChannelDescription,
    required NotificationContent content,
    required AppL10n l,
    int? overrideMinutesBefore,
    int allDayReminderHour = 9,
    String? viewerTz,
    bool skipExplicitCancel = false,
  }) async {
    final action = 'schedule:${event.id}';
    actions.add(action);
    trace?.add(action);
    if (event.id == throwOnEventId) {
      throw StateError('platform scheduling failed');
    }
    onScheduled?.call(event.id);
    return event.id == notArmedEventId
        ? null
        : eventNotificationId(ownerUserId, event.id);
  }
}

class _FakeNotificationRepo extends ApiNotificationRepository {
  _FakeNotificationRepo(this._get)
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  final Result<NotificationPreferences> Function() _get;

  @override
  Future<Result<NotificationPreferences>> get() async => _get();
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}
