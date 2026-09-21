// Durable state that bridges the notification background isolate and the app.
//
// The background isolate that handles a notification action (see
// notification_background_handler.dart) has NO Riverpod / Dio / secure storage —
// only SharedPreferences works there. So:
//   • a "Complete" tap can't call the API in-isolate → it's ENQUEUED here and
//     replayed by the app on next foreground (see pending_action_drainer.dart);
//   • a "Snooze" tap must re-schedule the reminder from the isolate → it reads
//     the notification's content back out of the META store, written by the
//     scheduler at schedule time.
//
// Both stores are plain JSON in SharedPreferences and safe to touch from either
// isolate. Keep the shapes backward-tolerant (all reads defensive) so an app
// update never trips over a value written by the previous version.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart' show AppL10n;
import 'package:readendar/features/notifications/notification_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPendingActionsKey = 'readendar_pending_notif_actions';
const _kPendingActionPrefix = 'readendar_pending_notif_action:';
const _kNotifMetaKey = 'readendar_notif_meta';

/// A deferred notification action awaiting replay by the app. Today only
/// `complete` is queued (snooze reschedules directly); the [action] field keeps
/// the shape open for future deferred actions.
@immutable
class PendingAction {
  const PendingAction({
    required this.action,
    required this.ownerUserId,
    required this.eventId,
    required this.ts,
  });

  factory PendingAction.fromJson(Map<String, dynamic> j) => PendingAction(
    action: j['a'] as String,
    ownerUserId: j['o'] as String,
    eventId: j['e'] as String,
    ts: (j['ts'] as num?)?.toInt() ?? 0,
  );

  final String action;
  final String ownerUserId;
  final String eventId;
  final int ts;

  Map<String, dynamic> toJson() => {
    'a': action,
    'o': ownerUserId,
    'e': eventId,
    'ts': ts,
  };

  // Value equality so the drainer can reconcile the queue by identity (remove
  // only the entries it processed, keeping any enqueued concurrently). `ts`
  // distinguishes two queued actions for the same event.
  @override
  bool operator ==(Object other) =>
      other is PendingAction &&
      other.action == action &&
      other.ownerUserId == ownerUserId &&
      other.eventId == eventId &&
      other.ts == ts;

  @override
  int get hashCode => Object.hash(action, ownerUserId, eventId, ts);
}

/// Durable deferred actions, one preference key per action.
///
/// The notification action handler runs in a separate isolate. A single JSON
/// array needs a cross-isolate read-modify-write and can therefore lose a tap
/// when the foreground isolate writes an older snapshot. Independent keys make
/// enqueue and acknowledgement additive/removal-only operations. The old array
/// remains readable and is migrated lazily so users can upgrade safely.
abstract final class PendingActionsStore {
  static Future<void> enqueue(SharedPreferences prefs, PendingAction a) async {
    await prefs.reload();
    await _migrateLegacy(prefs);
    await prefs.setString(_keyFor(a), jsonEncode(a.toJson()));
  }

  static List<PendingAction> readAll(SharedPreferences prefs) {
    final deduped = <PendingAction>{};
    final raw = prefs.getString(_kPendingActionsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map<String, dynamic>) {
              deduped.add(PendingAction.fromJson(entry));
            }
          }
        }
      } catch (_) {
        // A corrupt legacy queue must not prevent valid independent entries.
      }
    }
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_kPendingActionPrefix)) continue;
      final entry = prefs.getString(key);
      if (entry == null) continue;
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, dynamic>) {
          deduped.add(PendingAction.fromJson(decoded));
        }
      } catch (_) {
        // Ignore one corrupt entry and keep the remaining queue available.
      }
    }
    return deduped.toList()..sort((a, b) => a.ts.compareTo(b.ts));
  }

  /// Compatibility helper for tests and controlled complete replacements.
  /// Production draining uses [remove] so it never races an enqueue.
  static Future<void> writeAll(
    SharedPreferences prefs,
    List<PendingAction> list,
  ) async {
    await prefs.reload();
    await _migrateLegacy(prefs);
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_kPendingActionPrefix)) await prefs.remove(key);
    }
    for (final action in list) {
      await prefs.setString(_keyFor(action), jsonEncode(action.toJson()));
    }
  }

  /// Acknowledge only known actions. A concurrent isolate can enqueue a new
  /// key at any point without being overwritten or removed.
  static Future<void> remove(
    SharedPreferences prefs,
    Iterable<PendingAction> actions,
  ) async {
    await prefs.reload();
    await _migrateLegacy(prefs);
    for (final action in actions) {
      await prefs.remove(_keyFor(action));
    }
  }

  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.reload();
    await prefs.remove(_kPendingActionsKey);
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_kPendingActionPrefix)) await prefs.remove(key);
    }
  }

  static Future<void> _migrateLegacy(SharedPreferences prefs) async {
    final raw = prefs.getString(_kPendingActionsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            final action = PendingAction.fromJson(entry);
            await prefs.setString(_keyFor(action), jsonEncode(action.toJson()));
          }
        }
      }
    } catch (_) {
      // Drop a corrupt legacy value only after preserving every parsable entry.
    }
    await prefs.remove(_kPendingActionsKey);
  }

  static String _keyFor(PendingAction action) =>
      '$_kPendingActionPrefix${base64Url.encode(utf8.encode(jsonEncode(action.toJson())))}';
}

/// Everything the background isolate needs to re-fire (snooze) a notification
/// even when the app was killed: its content, channel, iOS category and the
/// exact Android action buttons — all captured at schedule time when a localized
/// [AppL10n] was available.
class NotifMeta {
  const NotifMeta({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
    required this.ownerUserId,
    required this.eventId,
    required this.categoryId,
    required this.androidActions,
    required this.payload,
    required this.tz,
  });

  factory NotifMeta.fromJson(Map<String, dynamic> j) => NotifMeta(
    title: j['t'] as String? ?? '',
    body: j['b'] as String?,
    channelName: j['cn'] as String? ?? '',
    channelDescription: j['cd'] as String? ?? '',
    ownerUserId: j['o'] as String? ?? '',
    eventId: j['e'] as String? ?? '',
    categoryId: j['ci'] as String? ?? '',
    androidActions: [
      for (final a in (j['aa'] as List? ?? const []))
        if (a is Map<String, dynamic>) NotifAction.fromJson(a),
    ],
    payload: j['p'] as String? ?? '',
    tz: j['tz'] as String?,
  );

  final String title;
  final String? body;
  final String channelName;
  final String channelDescription;
  final String ownerUserId;
  final String eventId;
  final String categoryId;
  final List<NotifAction> androidActions;
  final String payload;

  /// IANA zone the reminder fires in — used to compute "tonight 20:00". Null =
  /// device-local.
  final String? tz;

  Map<String, dynamic> toJson() => {
    't': title,
    'b': body,
    'cn': channelName,
    'cd': channelDescription,
    'o': ownerUserId,
    'e': eventId,
    'ci': categoryId,
    'aa': [for (final a in androidActions) a.toJson()],
    'p': payload,
    'tz': tz,
  };
}

/// Per-notification content keyed by the integer notification id. Written on
/// schedule, pruned on cancel, read by the snooze background handler.
///
/// A resync reschedules every event, so the naive one-`setString`-per-write path
/// would decode+encode+persist the whole map N times (O(N²) work + N disk
/// commits on each foreground return). [runBatched] coalesces a burst of
/// mutations into a single load + single flush. Main-isolate batches and direct
/// writes are serialized: lifecycle resync, a permission-dialog return, and an
/// explicit event save can otherwise overlap even though Dart runs one isolate.
abstract final class NotifMetaStore {
  /// The in-flight batch buffer, or null when writes persist immediately.
  static Map<String, dynamic>? _batch;
  static Object? _batchToken;
  static final Object _batchZoneKey = Object();
  static Future<void> _tail = Future<void>.value();

  static bool get _insideBatch =>
      _batch != null && identical(Zone.current[_batchZoneKey], _batchToken);

  /// Load the meta map once, run [body] (whose writes/removes mutate the buffer
  /// in memory), then persist a single time. Truly nested calls share the
  /// buffer; an unrelated concurrent call waits its turn.
  static Future<T> runBatched<T>(
    SharedPreferences prefs,
    Future<T> Function() body,
  ) async {
    if (_insideBatch) return body();
    return _serialized(() async {
      // Fold in a mutation from the notification background isolate before
      // taking this batch's snapshot.
      await prefs.reload();
      final token = Object();
      _batchToken = token;
      _batch = _readMap(prefs);

      late T result;
      Object? bodyError;
      StackTrace? bodyStack;
      try {
        result = await runZoned(
          body,
          zoneValues: {_batchZoneKey: token},
        );
      } on Object catch (error, stackTrace) {
        bodyError = error;
        bodyStack = stackTrace;
      }

      Object? flushError;
      StackTrace? flushStack;
      try {
        // Persist successful mutations even when a later platform schedule in
        // the same reconciliation failed. Those alarms are already armed and
        // still need their snooze metadata.
        await prefs.setString(_kNotifMetaKey, jsonEncode(_batch));
      } on Object catch (error, stackTrace) {
        flushError = error;
        flushStack = stackTrace;
      } finally {
        if (identical(_batchToken, token)) {
          _batch = null;
          _batchToken = null;
        }
      }

      if (bodyError != null) {
        Error.throwWithStackTrace(bodyError, bodyStack!);
      }
      if (flushError != null) {
        Error.throwWithStackTrace(flushError, flushStack!);
      }
      return result;
    });
  }

  static Future<void> write(
    SharedPreferences prefs,
    int notifId,
    NotifMeta meta,
  ) async {
    if (_insideBatch) {
      _batch!['$notifId'] = meta.toJson();
      return;
    }
    await _serialized(() async {
      await prefs.reload();
      final map = _readMap(prefs);
      map['$notifId'] = meta.toJson();
      await prefs.setString(_kNotifMetaKey, jsonEncode(map));
    });
  }

  static NotifMeta? read(SharedPreferences prefs, int notifId) {
    final entry = (_insideBatch ? _batch! : _readMap(prefs))['$notifId'];
    if (entry is! Map<String, dynamic>) return null;
    try {
      return NotifMeta.fromJson(entry);
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove(SharedPreferences prefs, int notifId) async {
    if (_insideBatch) {
      _batch!.remove('$notifId');
      return;
    }
    await _serialized(() async {
      await prefs.reload();
      final map = _readMap(prefs);
      if (map.remove('$notifId') == null) return;
      await prefs.setString(_kNotifMetaKey, jsonEncode(map));
    });
  }

  /// Drop every meta entry owned by [ownerUserId] — the meta twin of
  /// `cancelAllForUser` (logout on a shared device).
  static Future<void> removeForOwner(
    SharedPreferences prefs,
    String ownerUserId,
  ) async {
    bool ownedBy(Object? value) {
      if (value is! Map<String, dynamic>) return false;
      try {
        return NotifMeta.fromJson(value).ownerUserId == ownerUserId;
      } on Object catch (_) {
        return false;
      }
    }

    if (_insideBatch) {
      _batch!.removeWhere((_, v) => ownedBy(v));
      return;
    }
    await _serialized(() async {
      await prefs.reload();
      final map = _readMap(prefs);
      final before = map.length;
      map.removeWhere((_, v) => ownedBy(v));
      if (map.length == before) return;
      await prefs.setString(_kNotifMetaKey, jsonEncode(map));
    });
  }

  /// Stored metadata for [ownerUserId], keyed by platform notification id.
  /// Inside reconciliation this reads the active batch; elsewhere it reads the
  /// last committed snapshot.
  static Map<int, NotifMeta> entriesForOwner(
    SharedPreferences prefs,
    String ownerUserId,
  ) {
    final map = _insideBatch ? _batch! : _readMap(prefs);
    final result = <int, NotifMeta>{};
    for (final entry in map.entries) {
      final id = int.tryParse(entry.key);
      final value = entry.value;
      if (id == null || value is! Map<String, dynamic>) continue;
      try {
        final meta = NotifMeta.fromJson(value);
        if (meta.ownerUserId == ownerUserId) result[id] = meta;
      } on Object catch (_) {
        // Backward-tolerant: malformed entries are ignored and eventually
        // replaced by a successful schedule.
      }
    }
    return result;
  }

  static Map<String, dynamic> _readMap(SharedPreferences prefs) {
    final raw = prefs.getString(_kNotifMetaKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  /// FIFO mutex for main-isolate metadata operations.
  static Future<T> _serialized<T>(Future<T> Function() body) {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    return () async {
      await previous;
      try {
        return await body();
      } finally {
        release.complete();
      }
    }();
  }
}
