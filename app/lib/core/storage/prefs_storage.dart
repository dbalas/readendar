import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper around SharedPreferences for theme, locale, list filters, and
/// small per-book UI prefs.
class PrefsStorage {
  PrefsStorage(this._prefs);
  final SharedPreferences _prefs;
  final Map<String, Completer<void>> _readingChapterCacheMutations = {};

  static Future<PrefsStorage> open() async {
    final p = await SharedPreferences.getInstance();
    return PrefsStorage(p);
  }

  static const _kTheme = 'theme_mode';
  static const _kThemePreset = 'theme_preset';
  static const _kPremiumCoverAtmosphere = 'premium_cover_atmosphere';
  static const _kLocale = 'locale';
  static const _kChapterPromptHidden = 'chapter_progress_prompt_hidden:';
  static const _kReadingChapterCache = 'reading_chapter_cache:v1:';
  static const _kReadingChapterCacheIndex = 'reading_chapter_cache_index:v1:';
  static const _kWidgetCleanupPending = 'privacy_cleanup_widget_pending:v1';
  static const _kSpotlightCleanupPending =
      'privacy_cleanup_spotlight_pending:v1';
  static const int _readingChapterCacheMaxEntries = 24;
  static const int _readingChapterCacheMaxBytes = 1024 * 1024;
  static const int _readingChapterCacheMaxEntryBytes = 384 * 1024;

  /// Device-scoped first-run tour flag (shown at cold start).
  static const _kIntroSeen = 'onboarding_intro_seen';

  /// Legacy per-user keys from when the tour gated after profile setup.
  static const _kIntroSeenLegacyPrefix = 'onboarding_intro_seen:';
  static const _kCalendarSeenAt = 'calendar_novedades_seen_at:';
  static const _kQuoteDailyEnabled = 'quote_daily_enabled:';
  static const _kQuoteDailyHour = 'quote_daily_hour:';
  static const _kStoreReviewLastPromptMs = 'store_review_last_prompt_ms:';
  static const _kStoreReviewAttemptCount = 'store_review_attempt_count:';
  static const _kStoreReviewCompleted = 'store_review_completed:';
  static const _kStoreReviewDeclined = 'store_review_declined:';
  static const _kStoreReviewSessionCount = 'store_review_session_count:';
  // Legacy SharedPreferences prefix from pre-rename builds (read + migrate).
  static const _kLegacyProductFeedbackVisitCount =
      'community_feedback_visit_count:';
  static const _kLegacyProductFeedbackPrompted = 'community_feedback_prompted:';
  static const _kLegacyProductFeedbackCompleted =
      'community_feedback_completed:';
  static const _kLegacyProductFeedbackDeclined = 'community_feedback_declined:';
  static const _kProductFeedbackVisitCount = 'product_feedback_visit_count:';
  static const _kProductFeedbackPrompted = 'product_feedback_prompted:';
  static const _kProductFeedbackCompleted = 'product_feedback_completed:';
  static const _kProductFeedbackDeclined = 'product_feedback_declined:';
  static const _kAppUpdateSnoozedVersion = 'app_update_snoozed_version';
  static const _kAppUpdateLastCheckMs = 'app_update_last_check_ms';
  static const _kListFilters = 'list_filters:v1:';
  static const _kPlanUnit = 'plan_unit:';
  static const _kPlanMode = 'plan_mode:';
  static const _kRevealedSpoilerQuotesLegacy = 'revealed_spoiler_quotes:v1:';
  static const _kRevealedSpoilerQuoteBucket = 'revealed_spoiler_quotes:v2:';
  static const _spoilerRevealBucketCount = 64;

  String? getTheme() => _prefs.getString(_kTheme);
  Future<void> setTheme(String v) async => _prefs.setString(_kTheme, v);

  String? getThemePreset() => _prefs.getString(_kThemePreset);
  Future<bool> setThemePreset(String value) =>
      _prefs.setString(_kThemePreset, value);

  bool getPremiumCoverAtmosphereEnabled() =>
      _prefs.getBool(_kPremiumCoverAtmosphere) ?? false;
  Future<bool> setPremiumCoverAtmosphereEnabled(bool value) =>
      _prefs.setBool(_kPremiumCoverAtmosphere, value);

  String? getLocale() => _prefs.getString(_kLocale);
  Future<void> setLocale(String v) async => _prefs.setString(_kLocale, v);

  bool get isWidgetCleanupPending =>
      _prefs.getBool(_kWidgetCleanupPending) ?? false;
  bool get isSpotlightCleanupPending =>
      _prefs.getBool(_kSpotlightCleanupPending) ?? false;

  Future<bool> setWidgetCleanupPending(bool pending) => pending
      ? _prefs.setBool(_kWidgetCleanupPending, true)
      : _prefs.remove(_kWidgetCleanupPending);

  Future<bool> setSpotlightCleanupPending(bool pending) => pending
      ? _prefs.setBool(_kSpotlightCleanupPending, true)
      : _prefs.remove(_kSpotlightCleanupPending);

  /// Quote reveals are local, durable, and account-scoped on shared devices.
  Set<String> getRevealedSpoilerQuoteIds(String userId) {
    final ids = <String>{
      ...?_prefs.getStringList('$_kRevealedSpoilerQuotesLegacy$userId'),
    };
    for (var bucket = 0; bucket < _spoilerRevealBucketCount; bucket++) {
      ids.addAll(
        _prefs.getStringList(_spoilerRevealBucketKey(userId, bucket)) ??
            const [],
      );
    }
    ids.removeWhere((id) => id.trim().isEmpty);
    return ids;
  }

  Future<bool> revealSpoilerQuote(String userId, String quoteId) async {
    final normalizedId = quoteId.trim();
    if (userId.trim().isEmpty || normalizedId.isEmpty) return false;
    final legacy = _prefs.getStringList(
      '$_kRevealedSpoilerQuotesLegacy$userId',
    );
    if (legacy?.contains(normalizedId) ?? false) return true;
    final bucket = _spoilerRevealBucket(normalizedId);
    final key = _spoilerRevealBucketKey(userId, bucket);
    final ids = {...?_prefs.getStringList(key)};
    if (!ids.add(normalizedId)) return true;
    return _prefs.setStringList(key, ids.toList());
  }

  static String _spoilerRevealBucketKey(String userId, int bucket) =>
      '$_kRevealedSpoilerQuoteBucket$userId:$bucket';

  static int _spoilerRevealBucket(String quoteId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in quoteId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return (hash & 0x7fffffff) % _spoilerRevealBucketCount;
  }

  /// Whether the user dismissed the "update your page?" prompt that appears
  /// after completing a chapter milestone for this book (per-book, local-only).
  /// Book IDs are per-user copies, so this key is already scoped per account.
  bool isChapterPromptHidden(String bookId) =>
      _prefs.getBool('$_kChapterPromptHidden$bookId') ?? false;
  Future<void> setChapterPromptHidden(String bookId) async =>
      _prefs.setBool('$_kChapterPromptHidden$bookId', true);

  /// Small, account-scoped cache for closed-period stories and their archive.
  /// The backend remains authoritative; this only makes previously opened
  /// chapters available while offline and lets screens paint before refresh.
  String? getReadingChapterCache(String userId, String cacheKey) =>
      _prefs.getString('$_kReadingChapterCache$userId:$cacheKey');

  Future<bool> setReadingChapterCache(
    String userId,
    String cacheKey,
    String value,
  ) => _withReadingChapterCacheLock(userId, () async {
    if (userId.trim().isEmpty || cacheKey.trim().isEmpty) return false;
    final fullKey = '$_kReadingChapterCache$userId:$cacheKey';
    final indexKey = '$_kReadingChapterCacheIndex$userId';
    final valueBytes = utf8.encode(value).length;
    final index = <String>[
      ...?_prefs.getStringList(indexKey),
    ]..remove(fullKey);
    if (valueBytes > _readingChapterCacheMaxEntryBytes) {
      await _prefs.remove(fullKey);
      await _prefs.setStringList(indexKey, index);
      return false;
    }
    var totalBytes = valueBytes;
    for (final key in index) {
      totalBytes += utf8.encode(_prefs.getString(key) ?? '').length;
    }
    index.add(fullKey);
    while (index.length > _readingChapterCacheMaxEntries ||
        totalBytes > _readingChapterCacheMaxBytes) {
      final evicted = index.removeAt(0);
      totalBytes -= utf8.encode(_prefs.getString(evicted) ?? '').length;
      await _prefs.remove(evicted);
    }
    final saved = await _prefs.setString(fullKey, value);
    if (!saved) return false;
    final indexed = await _prefs.setStringList(indexKey, index);
    if (!indexed) await _prefs.remove(fullKey);
    return indexed;
  });

  Future<void> removeReadingChapterCache(
    String userId,
    String cacheKey,
  ) => _withReadingChapterCacheLock(userId, () async {
    final fullKey = '$_kReadingChapterCache$userId:$cacheKey';
    final indexKey = '$_kReadingChapterCacheIndex$userId';
    await _prefs.remove(fullKey);
    final index = <String>{...?_prefs.getStringList(indexKey)}..remove(fullKey);
    await _prefs.setStringList(indexKey, index.toList());
  });

  Future<void> clearReadingChapterCache(String userId) =>
      _withReadingChapterCacheLock(userId, () async {
        final indexKey = '$_kReadingChapterCacheIndex$userId';
        for (final key in _prefs.getStringList(indexKey) ?? const <String>[]) {
          await _prefs.remove(key);
        }
        await _prefs.remove(indexKey);
      });

  Future<T> _withReadingChapterCacheLock<T>(
    String userId,
    Future<T> Function() mutation,
  ) async {
    final previous = _readingChapterCacheMutations[userId];
    final current = Completer<void>();
    _readingChapterCacheMutations[userId] = current;
    if (previous != null) await previous.future;
    try {
      return await mutation();
    } finally {
      current.complete();
      if (identical(_readingChapterCacheMutations[userId], current)) {
        _readingChapterCacheMutations.remove(userId);
      }
    }
  }

  /// Whether the first-run feature-tour carousel has been seen/dismissed.
  /// Device-local only (no backend). The tour runs at cold start;
  /// once skipped or finished it must not replay on later launches.
  ///
  /// Also treats legacy per-user `onboarding_intro_seen:<userId>` keys as seen
  /// so profiles that finished the old gated tour are not nagged again. A
  /// legacy hit promotes to the device key (in-memory immediately; disk async)
  /// so later reads skip the key scan.
  bool isIntroSeen() {
    if (_prefs.getBool(_kIntroSeen) ?? false) return true;
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_kIntroSeenLegacyPrefix) &&
          (_prefs.getBool(key) ?? false)) {
        // SharedPreferences updates its cache before awaiting disk I/O.
        unawaited(_prefs.setBool(_kIntroSeen, true));
        return true;
      }
    }
    return false;
  }

  Future<void> setIntroSeen() async => _prefs.setBool(_kIntroSeen, true);

  /// Epoch-ms of the last time the user opened the Calendar tab. Drives the
  /// bottom-nav "novedades" dot: events that turned new/modified after this
  /// instant are still unseen. Local-only (no backend), keyed per user so one
  /// account's acknowledgement never silences another's on a shared device.
  int getCalendarSeenAt(String userId) =>
      _prefs.getInt('$_kCalendarSeenAt$userId') ?? 0;
  Future<void> setCalendarSeenAt(String userId, int epochMs) async =>
      _prefs.setInt('$_kCalendarSeenAt$userId', epochMs);

  /// Opt-in daily "quote of the day" local notification (per user; local-only
  /// like other device prefs — no backend column).
  bool getQuoteDailyEnabled(String userId) =>
      _prefs.getBool('$_kQuoteDailyEnabled$userId') ?? false;
  Future<void> setQuoteDailyEnabled(String userId, bool v) async =>
      _prefs.setBool('$_kQuoteDailyEnabled$userId', v);

  /// Local hour (0–23) the daily quote fires at. Default 9:00.
  int getQuoteDailyHour(String userId) =>
      _prefs.getInt('$_kQuoteDailyHour$userId') ?? 9;
  Future<void> setQuoteDailyHour(String userId, int hour) async =>
      _prefs.setInt('$_kQuoteDailyHour$userId', hour);

  /// Epoch-ms of the last store-review soft prompt. 0 = never prompted.
  int getStoreReviewLastPromptMs(String userId) =>
      _prefs.getInt('$_kStoreReviewLastPromptMs$userId') ?? 0;
  Future<void> setStoreReviewLastPromptMs(String userId, int epochMs) async =>
      _prefs.setInt('$_kStoreReviewLastPromptMs$userId', epochMs);

  /// How many times the store-review modal was shown (lifetime, per user).
  int getStoreReviewAttemptCount(String userId) =>
      _prefs.getInt('$_kStoreReviewAttemptCount$userId') ?? 0;
  Future<void> setStoreReviewAttemptCount(String userId, int count) async =>
      _prefs.setInt('$_kStoreReviewAttemptCount$userId', count);

  /// User tapped through to the store once — stop soft-prompting.
  bool isStoreReviewCompleted(String userId) =>
      _prefs.getBool('$_kStoreReviewCompleted$userId') ?? false;
  Future<void> setStoreReviewCompleted(String userId) async =>
      _prefs.setBool('$_kStoreReviewCompleted$userId', true);

  /// User dismissed the soft prompt ("Not now" / barrier). Soft triggers never
  /// ask again; Settings can still open the store on explicit intent.
  bool isStoreReviewDeclined(String userId) =>
      _prefs.getBool('$_kStoreReviewDeclined$userId') ?? false;
  Future<void> setStoreReviewDeclined(String userId) async =>
      _prefs.setBool('$_kStoreReviewDeclined$userId', true);

  /// Local count of completed personal reading-milestone sessions. Used to
  /// gate the habit-based store-review trigger (not a server source of truth).
  int getStoreReviewSessionCount(String userId) =>
      _prefs.getInt('$_kStoreReviewSessionCount$userId') ?? 0;
  Future<int> incrementStoreReviewSessionCount(String userId) async {
    final next = getStoreReviewSessionCount(userId) + 1;
    await _prefs.setInt('$_kStoreReviewSessionCount$userId', next);
    return next;
  }

  /// Records that a soft prompt was shown (timestamp + attempt counter).
  Future<void> recordStoreReviewPrompt(String userId, DateTime at) async {
    await setStoreReviewLastPromptMs(userId, at.millisecondsSinceEpoch);
    await setStoreReviewAttemptCount(
      userId,
      getStoreReviewAttemptCount(userId) + 1,
    );
  }

  /// Local count of root-tab entries with an onboarded session.
  /// Gates the soft in-app feedback prompt (not a server source of truth).
  int getProductFeedbackVisitCount(String userId) =>
      _prefs.getInt('$_kProductFeedbackVisitCount$userId') ??
      _prefs.getInt('$_kLegacyProductFeedbackVisitCount$userId') ??
      0;
  Future<int> incrementProductFeedbackVisitCount(String userId) async {
    final next = getProductFeedbackVisitCount(userId) + 1;
    await _prefs.setInt('$_kProductFeedbackVisitCount$userId', next);
    await _prefs.remove('$_kLegacyProductFeedbackVisitCount$userId');
    return next;
  }

  /// Soft in-app feedback modal was shown once.
  bool isProductFeedbackPrompted(String userId) =>
      _prefs.getBool('$_kProductFeedbackPrompted$userId') ??
      _prefs.getBool('$_kLegacyProductFeedbackPrompted$userId') ??
      false;
  Future<void> setProductFeedbackPrompted(String userId) async {
    await _prefs.setBool('$_kProductFeedbackPrompted$userId', true);
    await _prefs.remove('$_kLegacyProductFeedbackPrompted$userId');
  }

  /// User tapped through to the feedback form from the soft prompt.
  bool isProductFeedbackCompleted(String userId) =>
      _prefs.getBool('$_kProductFeedbackCompleted$userId') ??
      _prefs.getBool('$_kLegacyProductFeedbackCompleted$userId') ??
      false;
  Future<void> setProductFeedbackCompleted(String userId) async {
    await _prefs.setBool('$_kProductFeedbackCompleted$userId', true);
    await _prefs.remove('$_kLegacyProductFeedbackCompleted$userId');
  }

  /// User dismissed the in-app feedback soft prompt.
  bool isProductFeedbackDeclined(String userId) =>
      _prefs.getBool('$_kProductFeedbackDeclined$userId') ??
      _prefs.getBool('$_kLegacyProductFeedbackDeclined$userId') ??
      false;
  Future<void> setProductFeedbackDeclined(String userId) async {
    await _prefs.setBool('$_kProductFeedbackDeclined$userId', true);
    await _prefs.remove('$_kLegacyProductFeedbackDeclined$userId');
  }

  /// Device-scoped store version last snoozed (Later or Update). Empty = none.
  String? getAppUpdateSnoozedVersion() {
    final v = _prefs.getString(_kAppUpdateSnoozedVersion);
    if (v == null || v.isEmpty) return null;
    return v;
  }

  Future<void> setAppUpdateSnoozedVersion(String token) async =>
      _prefs.setString(_kAppUpdateSnoozedVersion, token);

  /// Epoch-ms of the last completed store-update check. 0 = never.
  int getAppUpdateLastCheckMs() => _prefs.getInt(_kAppUpdateLastCheckMs) ?? 0;
  Future<void> setAppUpdateLastCheckMs(int epochMs) async =>
      _prefs.setInt(_kAppUpdateLastCheckMs, epochMs);

  /// Applied catalog/list sheet filters for [screenId]. Device-scoped JSON.
  /// Search query is never stored here. Empty [screenId] is ignored.
  String? getListFiltersJson(String screenId) {
    if (screenId.trim().isEmpty) return null;
    return _prefs.getString('$_kListFilters$screenId');
  }

  Future<bool> setListFiltersJson(String screenId, String json) {
    if (screenId.trim().isEmpty) return Future<bool>.value(false);
    return _prefs.setString('$_kListFilters$screenId', json);
  }

  Future<bool> clearListFilters(String screenId) {
    if (screenId.trim().isEmpty) return Future<bool>.value(false);
    return _prefs.remove('$_kListFilters$screenId');
  }

  /// Last plan unit the user chose (`pages` | `chapters`). Local-only, keyed
  /// per user so the next plan opens on their preferred unit.
  String? getPlanUnit(String userId) => _prefs.getString('$_kPlanUnit$userId');
  Future<void> setPlanUnit(String userId, String unit) async =>
      _prefs.setString('$_kPlanUnit$userId', unit);

  /// Last planning goal the user chose (`pace` | `deadline` | `before_event`).
  /// Local-only and account-scoped, matching the plan-unit preference.
  String? getPlanMode(String userId) => _prefs.getString('$_kPlanMode$userId');
  Future<void> setPlanMode(String userId, String mode) async =>
      _prefs.setString('$_kPlanMode$userId', mode);

  static const _kDataPlane = 'data_plane:v1';
  static const _kMigrationBannerHidden = 'migration_banner_hidden:v1';
  static const _kLocalProfile = 'local_profile:v1';
  static const _kImportCheckpoint = 'import_checkpoint:v1';

  String? getDataPlane() => _prefs.getString(_kDataPlane);
  Future<void> setDataPlane(String value) async =>
      _prefs.setString(_kDataPlane, value);

  bool isMigrationBannerHidden() =>
      _prefs.getBool(_kMigrationBannerHidden) ?? false;
  Future<void> setMigrationBannerHidden(bool value) async =>
      _prefs.setBool(_kMigrationBannerHidden, value);

  static const _kMigrationPromptDismissed = 'migration_prompt_dismissed:v1';

  bool isMigrationPromptDismissed() =>
      _prefs.getBool(_kMigrationPromptDismissed) ?? false;
  Future<void> setMigrationPromptDismissed(bool value) async =>
      _prefs.setBool(_kMigrationPromptDismissed, value);

  String? getLocalProfileJson() => _prefs.getString(_kLocalProfile);
  Future<void> setLocalProfileJson(String json) async =>
      _prefs.setString(_kLocalProfile, json);

  String? getImportCheckpointJson() => _prefs.getString(_kImportCheckpoint);
  Future<void> setImportCheckpointJson(String json) async =>
      _prefs.setString(_kImportCheckpoint, json);
  Future<void> clearImportCheckpoint() async =>
      _prefs.remove(_kImportCheckpoint);

  /// Serializable prefs restored with a local backup (theme, filters, plan UI).
  Map<String, Object> snapshotForBackup() {
    final out = <String, Object>{};
    for (final key in _prefs.getKeys()) {
      if (!_includePrefInBackup(key)) continue;
      final value = _readPrefForBackup(key);
      if (value != null) out[key] = value;
    }
    return out;
  }

  Future<void> restoreFromBackup(Map<String, dynamic> snapshot) async {
    for (final key in _prefs.getKeys()) {
      if (_includePrefInBackup(key)) {
        await _prefs.remove(key);
      }
    }
    for (final entry in snapshot.entries) {
      final key = entry.key;
      if (!_includePrefInBackup(key)) continue;
      final value = entry.value;
      if (value is bool) {
        await _prefs.setBool(key, value);
      } else if (value is int) {
        await _prefs.setInt(key, value);
      } else if (value is double) {
        await _prefs.setDouble(key, value);
      } else if (value is String) {
        await _prefs.setString(key, value);
      } else if (value is List) {
        await _prefs.setStringList(
          key,
          value.map((e) => e.toString()).toList(),
        );
      }
    }
  }

  bool _includePrefInBackup(String key) {
    if (key == _kImportCheckpoint) return false;
    if (key == _kDataPlane) return false;
    if (key == _kLocalProfile) return false;
    if (key == _kMigrationBannerHidden) return false;
    if (key == _kMigrationPromptDismissed) return false;
    if (key == _kWidgetCleanupPending) return false;
    if (key == _kSpotlightCleanupPending) return false;
    if (key.startsWith(_kStoreReviewLastPromptMs)) return false;
    if (key.startsWith(_kStoreReviewAttemptCount)) return false;
    if (key.startsWith(_kStoreReviewCompleted)) return false;
    if (key.startsWith(_kStoreReviewDeclined)) return false;
    if (key.startsWith(_kStoreReviewSessionCount)) return false;
    if (key.startsWith(_kProductFeedbackVisitCount)) return false;
    if (key.startsWith(_kProductFeedbackPrompted)) return false;
    if (key.startsWith(_kProductFeedbackCompleted)) return false;
    if (key.startsWith(_kProductFeedbackDeclined)) return false;
    if (key.startsWith(_kLegacyProductFeedbackVisitCount)) return false;
    if (key.startsWith(_kLegacyProductFeedbackPrompted)) return false;
    if (key.startsWith(_kLegacyProductFeedbackCompleted)) return false;
    if (key.startsWith(_kLegacyProductFeedbackDeclined)) return false;
    if (key.startsWith(_kAppUpdateSnoozedVersion)) return false;
    if (key.startsWith(_kAppUpdateLastCheckMs)) return false;
    if (key.startsWith(_kRevealedSpoilerQuotesLegacy)) return false;
    if (key.startsWith(_kRevealedSpoilerQuoteBucket)) return false;
    if (key.startsWith(_kReadingChapterCache)) return false;
    if (key.startsWith(_kReadingChapterCacheIndex)) return false;
    return true;
  }

  Object? _readPrefForBackup(String key) {
    final value = _prefs.get(key);
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return value;
  }
}
